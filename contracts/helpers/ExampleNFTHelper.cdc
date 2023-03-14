import WithdrawHelper from "../WithdrawHelper.cdc"
import ExampleNFT from "../ExampleNFT.cdc"
import NonFungibleToken from "../NonFungibleToken.cdc"
import MetadataViews from "../MetadataViews.cdc"

pub contract ExampleNFTWithdrawHelper {
    pub let PublicPath: PublicPath
    pub let StoragePath: StoragePath

    pub resource ExampleNFTWithdrawer: WithdrawHelper.Withdrawer {
        access(contract) let nftType: Type

        pub fun withdraw(nftID: UInt64, expectedType: Type, cap: Capability<&{NonFungibleToken.Provider}>): @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver} {
            let nft <- cap.borrow()!.withdraw(withdrawID: nftID) as! @ExampleNFT.NFT
            return <- nft
        }

        init() {
            self.nftType = Type<@ExampleNFT.NFT>()
        }
    }

    init() {
        let helper <- create ExampleNFTWithdrawer()
        let identifier = WithdrawHelper.getPathIdentifier(helper.nftType)

        self.PublicPath = PublicPath(identifier: identifier)!
        self.StoragePath = StoragePath(identifier: identifier)!
        
        self.account.save(<-helper, to: self.StoragePath)
        self.account.link<&{WithdrawHelper.Withdrawer}>(self.PublicPath, target: self.StoragePath)
    }
}