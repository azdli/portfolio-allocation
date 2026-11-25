// A demo for trying the app before setting up a portfolio

import Foundation

enum SampleData {
    static var portfolio: Portfolio {
        let fidelityRoth = Account(brokerage: "Fidelity", name: "Roth IRA")
        let fidelityBrokerage = Account(brokerage: "Fidelity", name: "Brokerage")
        let fidelityHSA = Account(brokerage: "Fidelity", name: "HSA")
        let schwabBrokerage = Account(brokerage: "Schwab", name: "Brokerage")
        let schwabIRA = Account(brokerage: "Schwab", name: "Traditional IRA")
        let vanguard401k = Account(brokerage: "Vanguard", name: "401(k)")
        let vanguardRoth = Account(brokerage: "Vanguard", name: "Roth IRA")
        let merrillBrokerage = Account(brokerage: "Merrill", name: "Brokerage")

        let vti = Asset(symbol: "VTI", name: "Vanguard Total Stock Market ETF", assetClass: .usStocks, price: 298.40, targetPercent: 40)
        let vxus = Asset(symbol: "VXUS", name: "Vanguard Total International Stock ETF", assetClass: .internationalStocks, price: 67.10, targetPercent: 25)
        let bnd = Asset(symbol: "BND", name: "Vanguard Total Bond Market ETF", assetClass: .bonds, price: 73.25, targetPercent: 15)
        let qqqm = Asset(symbol: "QQQM", name: "Invesco NASDAQ 100 ETF", assetClass: .usStocks, price: 212.80, targetPercent: 10)
        let aapl = Asset(symbol: "AAPL", name: "Apple Inc.", assetClass: .usStocks, price: 231.50, targetPercent: nil)
        let cash = Asset(symbol: "CASH", name: "Cash & money market", assetClass: .cash, price: 1, targetPercent: 5)

        func position(_ asset: Asset, _ account: Account, _ shares: Double, _ cost: Double) -> Position {
            Position(assetID: asset.id, accountID: account.id, shares: shares, costBasis: cost)
        }

        return Portfolio(
            accounts: [fidelityRoth, fidelityBrokerage, fidelityHSA, schwabBrokerage, schwabIRA, vanguard401k, vanguardRoth, merrillBrokerage],
            assets: [vti, vxus, bnd, qqqm, aapl, cash],
            positions: [
                position(vti, fidelityRoth, 60, 12_100),
                position(vti, fidelityBrokerage, 45, 9_800),
                position(vti, schwabBrokerage, 80, 17_600),
                position(vti, vanguard401k, 50, 11_700),
                position(vti, vanguardRoth, 30, 6_300),
                position(vxus, fidelityRoth, 150, 8_700),
                position(vxus, schwabIRA, 260, 15_100),
                position(vxus, vanguardRoth, 120, 7_050),
                position(bnd, vanguard401k, 280, 20_720),
                position(bnd, schwabIRA, 90, 6_570),
                position(qqqm, schwabBrokerage, 60, 9_400),
                position(qqqm, fidelityHSA, 25, 4_050),
                position(aapl, merrillBrokerage, 40, 6_400),
                position(cash, fidelityBrokerage, 2_100, 2_100),
                position(cash, schwabBrokerage, 4_350, 4_350),
                position(cash, fidelityHSA, 800, 800),
                position(cash, merrillBrokerage, 1_200, 1_200),
            ]
        )
    }
}
