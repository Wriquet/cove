import XCTest
@testable import Cove

final class LocalizationTests: XCTestCase {
    private var previousLanguage: AppLanguage = .system

    override func setUp() {
        super.setUp()
        previousLanguage = LanguageManager.shared.language
    }

    override func tearDown() {
        LanguageManager.shared.language = previousLanguage
        super.tearDown()
    }

    func testChineseLocalizationLoadsKeyStrings() {
        LanguageManager.shared.language = .zhHans
        XCTAssertEqual(L10n.tr("New Connection"), "新建连接")
        XCTAssertEqual(L10n.tr("Review Changes"), "预览更改")
        XCTAssertEqual(L10n.tr("Run Current"), "运行当前查询")
        XCTAssertEqual(L10n.treeNodeLabel("Tables", icon: "folder"), "表")
        XCTAssertEqual(L10n.treeNodeLabel("Tables", icon: "tablecells"), "Tables")
        XCTAssertEqual(L10n.optionLabel("Yes"), "是")
        XCTAssertEqual(L10n.completionDetail("keyword"), "关键字")
        XCTAssertEqual(ConnectionEnvironment.production.displayName, "生产环境")
        XCTAssertEqual(SSHAuthMethod.privateKey.displayName, "私钥")
    }

    func testEnglishLocalizationLoadsKeyStrings() {
        LanguageManager.shared.language = .en
        XCTAssertEqual(L10n.tr("New Connection"), "New Connection")
        XCTAssertEqual(L10n.treeNodeLabel("Tables", icon: "folder"), "Tables")
        XCTAssertEqual(ConnectionEnvironment.production.displayName, "Production")
    }

    func testFormattedPageInfoInChinese() {
        LanguageManager.shared.language = .zhHans
        let result = QueryResult(
            columns: [ColumnInfo(name: "id", typeName: "int", isPrimaryKey: true)],
            rows: [["1"], ["2"]],
            rowsAffected: nil,
            totalCount: 2
        )
        let state = TableState(tablePath: ["db", "public", "Tables", "users"], result: result)
        XCTAssertTrue(state.pageInfo.contains("第 1-2 行"))
        XCTAssertTrue(state.pageInfo.contains("第 1/1 页"))
    }
}
