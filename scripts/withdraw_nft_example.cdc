import WithdrawHelper from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7

pub fun main(addr: Address, nftID: UInt64, expectedTypeIdentifier: String, storagePath: String): String {
  let authAcct = getAuthAccount(addr)
  let p = /private/temp12345
  authAcct.link<&{NonFungibleToken.Provider}>(p, target: StoragePath(identifier: storagePath)!)
  let c = authAcct.getCapability<&{NonFungibleToken.Provider}>(p)

  let expectedType = CompositeType(expectedTypeIdentifier)!
  let nft <- WithdrawHelper.withdraw(nftID: nftID, expectedType: expectedType, cap: c) as! @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver}
  destroy nft

  return "Done!"
}
