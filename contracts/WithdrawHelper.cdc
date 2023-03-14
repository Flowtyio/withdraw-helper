import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"
import StringUtils from "./StringUtils.cdc"

/*
WithdrawHelper
Dapper Wallet offers don't talk in terms of NFT resources because they were made before default implementations
existed. Instead of talking in terms of NFT resources, it uses an interface conformance of @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver}
for offers resolution.
*/
pub contract WithdrawHelper {
    pub let StoragePath: StoragePath

    pub resource interface Withdrawer {
        access(contract) let nftType: Type

        pub fun withdraw(nftID: UInt64, expectedType: Type, provider: &{NonFungibleToken.Provider}): @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver} {
            pre {
                expectedType == self.nftType: "expectedType does not match withdrawer nftType"
            }

            post {
                result != nil: "no nft withdrawn"
                result!.getType() == expectedType: "incorrect nft type"
            }
        }
    }

    pub fun getPathIdentifier(_ type: Type): String {
        let segments = StringUtils.split(type.identifier, ".")
        return StringUtils.join(["WithdrawHelper", segments[1], segments[2]], "")
    }

    pub fun withdraw(nftID: UInt64, expectedType: Type, provider: &{NonFungibleToken.Provider}): @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver} {
        let idenfitier = WithdrawHelper.getPathIdentifier(expectedType)
        let s = PublicPath(identifier: idenfitier)!
        return <- self.account.getCapability<&{Withdrawer}>(s).borrow()!.withdraw(nftID: nftID, expectedType: expectedType, provider: provider)
    }

    pub resource Admin {
        pub fun deployTemplate(nftType: Type) {
            let segments = StringUtils.split(nftType.identifier, ".")
            let contractName = segments[2]
            let addressString = "0x".concat(segments[1])

            let generatedName = contractName.concat(addressString).concat("WithdrawHelper")
            let templateCode = WithdrawHelper.getTemplate(contractName: contractName, addressString: addressString, generatedName: generatedName).utf8
            WithdrawHelper.account.contracts.add(name: generatedName, code: templateCode)
        }

        pub fun updateTemplate(nftType: Type) {
            let segments = StringUtils.split(nftType.identifier, ".")
            let contractName = segments[2]
            let addressString = "0x".concat(segments[1])

            let generatedName = contractName.concat(addressString).concat("WithdrawHelper")
            let templateCode = WithdrawHelper.getTemplate(contractName: contractName, addressString: addressString, generatedName: generatedName).utf8
            WithdrawHelper.account.contracts.update__experimental(name: generatedName, code: templateCode)  
        }
    }

    pub fun getTemplate(contractName: String, addressString: String, generatedName: String): String {
        let withdrawHelperAddress = self.account.address

        let nftAddress = StringUtils.fromType(Type<NonFungibleToken>())
        let stringUtilsAddress = Type<StringUtils>()

        return ""
                .concat("import WithdrawHelper from ").concat(withdrawHelperAddress.toString()).concat("\n")
                .concat("import NonFungibleToken from ").concat(nftAddress).concat("\n")
                .concat("import MetadataViews from ").concat(nftAddress).concat("\n")
                .concat("import ").concat(contractName).concat(" from ").concat(addressString).concat("\n\n")
                .concat("pub contract ").concat(generatedName).concat(" {\n")
                .concat("   pub let PublicPath: PublicPath\n")
                .concat("   pub let StoragePath: StoragePath\n")
                .concat("\n")
                .concat("   pub resource Withdrawer: WithdrawHelper.Withdrawer {\n")
                .concat("       access(contract) let nftType: Type\n\n")
                .concat("       pub fun withdraw(nftID: UInt64, expectedType: Type, provider: &{NonFungibleToken.Provider}): @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver} {\n")
                .concat("           let nft <- provider.withdraw(withdrawID: nftID) as! @").concat(contractName).concat(".NFT\n")
                .concat("           return <- nft\n")
                .concat("       }\n")
                .concat("\n")
                .concat("       init() {\n")
                .concat("           self.nftType = Type<@").concat(contractName).concat(".NFT>()\n")
                .concat("       }\n")
                .concat("   }\n")
                .concat("\n\n")
                .concat("   init() {\n")
                .concat("       let helper <- create Withdrawer()\n")
                .concat("       let identifier = WithdrawHelper.getPathIdentifier(helper.nftType)\n")
                .concat("       self.PublicPath = PublicPath(identifier: identifier)!\n")
                .concat("       self.StoragePath = StoragePath(identifier: identifier)!\n\n")
                .concat("       self.account.save(<-helper, to: self.StoragePath)\n")
                .concat("       self.account.link<&{WithdrawHelper.Withdrawer}>(self.PublicPath, target: self.StoragePath)\n")
                .concat("   }\n")
                .concat("}\n")
    }

    init() {
        self.StoragePath = /storage/WithdrawHelperAdmin
        self.account.save(<- create Admin(), to: self.StoragePath)
    }
}
 