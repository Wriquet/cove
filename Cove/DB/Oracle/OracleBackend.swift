import Foundation
import OracleNIO
import Logging

final class OracleBackend: DatabaseBackend, @unchecked Sendable {
    let name = "Oracle"
    let client: OracleClient
    private let runningTask: Task<Void, Never>

    let syntaxKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "SET",
        "CREATE", "DROP", "ALTER", "TABLE", "INDEX", "VIEW", "SCHEMA",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "CROSS", "ON", "AS",
        "AND", "OR", "NOT", "IN", "IS", "NULL", "LIKE", "BETWEEN", "EXISTS",
        "ORDER", "BY", "GROUP", "HAVING", "DISTINCT",
        "UNION", "ALL", "CASE", "WHEN", "THEN", "ELSE", "END", "BEGIN",
        "COMMIT", "ROLLBACK", "VALUES", "DEFAULT", "PRIMARY",
        "KEY", "FOREIGN", "REFERENCES", "CASCADE", "CONSTRAINT", "CHECK",
        "UNIQUE", "ASC", "DESC", "WITH", "RETURNING", "GRANT",
        "REVOKE", "TRUNCATE", "TRIGGER", "FUNCTION", "PROCEDURE",
        "IF", "LOOP", "WHILE", "FOR", "FETCH", "CURSOR", "DECLARE", "EXECUTE",
        "NUMBER", "VARCHAR2", "NVARCHAR2", "CHAR", "NCHAR", "CLOB", "NCLOB",
        "BLOB", "DATE", "TIMESTAMP", "INTERVAL", "RAW", "BOOLEAN",
        "BINARY_FLOAT", "BINARY_DOUBLE", "INTEGER", "FLOAT",
        "TRUE", "FALSE", "COUNT", "SUM", "AVG", "MIN", "MAX",
        "COALESCE", "CAST", "OVER", "PARTITION", "ROW_NUMBER", "RANK",
        "DENSE_RANK", "LAG", "LEAD", "FIRST_VALUE", "LAST_VALUE",
        "SYSDATE", "SYSTIMESTAMP", "ROWNUM", "ROWID", "DUAL",
        "NVL", "NVL2", "DECODE", "TO_DATE", "TO_CHAR", "TO_NUMBER", "TRUNC",
        "MINUS", "CONNECT", "START", "LEVEL", "PRIOR",
        "PIVOT", "UNPIVOT", "MERGE", "USING", "MATCHED",
        "PACKAGE", "BODY", "REPLACE", "FORCE", "PURGE",
        "MATERIALIZED", "SEQUENCE", "SYNONYM", "TYPE",
        "OFFSET", "ROWS", "ONLY", "NEXT",
    ]

    private init(client: OracleClient, runningTask: Task<Void, Never>) {
        self.client = client
        self.runningTask = runningTask
    }

    static func connect(config: ConnectionConfig) async throws -> OracleBackend {
        let port = Int(config.port) ?? 1521
        let oraConfig = try await resolveConfiguration(config: config, port: port)

        let client = OracleClient(configuration: oraConfig)
        let task = Task { await client.run() }

        do {
            try await client.withConnection { conn in
                try await conn.execute(OracleStatement(unsafeSQL: "SELECT 1 FROM DUAL"))
            }
        } catch let error as OracleSQLError {
            task.cancel()
            throw DbError.connection(error.serverMessage)
        } catch {
            task.cancel()
            throw DbError.connection(String(describing: error))
        }

        return OracleBackend(client: client, runningTask: task)
    }

    private static func resolveConfiguration(
        config: ConnectionConfig,
        port: Int
    ) async throws -> OracleConnection.Configuration {
        let logger = Logger(label: "cove.oracle")

        func makeConfig(service: OracleServiceMethod) -> OracleConnection.Configuration {
            var cfg = OracleConnection.Configuration(
                host: config.host,
                port: port,
                service: service,
                username: config.user,
                password: config.password
            )
            // Avoid oracle-nio 1.0.0-rc.4 bug where OOB check on Oracle 19c (TNS 318)
            // erroneously enables 23ai fastAuth and causes uncleanShutdown.
            cfg.disableOOB = true
            return cfg
        }

        let serviceConfig = makeConfig(service: .serviceName(config.database))
        do {
            let conn = try await OracleConnection.connect(
                configuration: serviceConfig,
                id: 1,
                logger: logger
            )
            try? await conn.close()
            return serviceConfig
        } catch let error as OracleSQLError where isInvalidServiceName(error) {
            let sidConfig = makeConfig(service: .sid(config.database))
            do {
                let conn = try await OracleConnection.connect(
                    configuration: sidConfig,
                    id: 2,
                    logger: logger
                )
                try? await conn.close()
                return sidConfig
            } catch let sidError as OracleSQLError {
                throw DbError.connection(sidError.serverMessage)
            } catch {
                throw DbError.connection(String(describing: error))
            }
        } catch let error as OracleSQLError {
            throw DbError.connection(error.serverMessage)
        } catch {
            throw DbError.connection(String(describing: error))
        }
    }

    private static func isInvalidServiceName(_ error: OracleSQLError) -> Bool {
        if error.serverInfo?.number == 12514 {
            return true
        }
        return String(describing: error).contains("12514")
    }

    deinit {
        runningTask.cancel()
    }

    func quoteIdentifier(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

extension OracleSQLError {
    var serverMessage: String {
        serverInfo?.message ?? String(describing: self)
    }
}
