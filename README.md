# WithdrawHelper


## Problem

One of the problems with Dapper Wallet offers has to do with before default implementations
were deployed. Offers needed a generic way to resolve metadata on the NFTs which were being used
to accept them, but the type `@NonFungibleToken.NFT` didn't have a way to yield metadata. 

Because of that, the contract used by Dapper for Offers takes in an interface conformance which **most** collections
adhere to. That conforomance is `@AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver}`. These two interfaces
give Dapper all the things it needs to resolve data (`MetadataViews.Resolver`) while still ensuring that the resource 
is an NFT (`NonFungibleToken.INFT`).

The problem, however, is that withdrawing an NFT using the `NonFungibleToken.Provider` method doesn't adhere to this interface
pattern. Instead, you must cast to the actual NFT type that you are withdrawing, and it will adhere to both the needed interfaces 
to be used for offer acceptance. And because of that, a new transaction for every collection on Dapper Wallet would be needed for 
which is a manual approval process. 

## Solution

This repo is a contract that deploys other contracts. It exposes an interface which will take a `NonFungibleToken.Provider`
capability, and return an `@AnyResource{NonFungibleToken.NFT, MetadataViews.Resolver}`. It will do this 
by generating a contract which imports the type we want a template for which does the casting for us, enabling a transaction to give
a capability and nft id, and a resource with the proper conformance will come back.

## Example

We can read the contract code which would be deployed by calling `getTemplate`

```cadence
import ExampleNFT from 0xf8d6e0586b0a20c7
import WithdrawHelper from 0xf8d6e0586b0a20c7
import StringUtils from 0xf8d6e0586b0a20c7

pub fun main():String {
  let t = Type<@ExampleNFT.NFT>()
  let segments = StringUtils.split(t.identifier, ".")
  let contractName = segments[2]
  let addressString = "0x".concat(segments[1])
  return WithdrawHelper.getTemplate(contractName: contractName, addressString: addressString)
}
```

We can generate a new contract using the `Admin` resource

```cadence
import WithdrawHelper from 0xf8d6e0586b0a20c7
import StringUtils from 0xf8d6e0586b0a20c7

transaction(identifier: String) {
  let admin: &WithdrawHelper.Admin
  prepare(acct: AuthAccount) {
    self.admin = acct.borrow<&WithdrawHelper.Admin>(from: WithdrawHelper.StoragePath) ?? panic("admin not found")
  }
  
  execute {
    let t = CompositeType(identifier)!
    self.admin.deployTemplate(nftType: t)
  }
}
```

Then we can use the new contract, routing through the main `WithdrawHelper` contract to borrow the correct resolver by nft type.
Note that we can cast to the correct conformance in this script because the helper has done the heavy-lifting for us
```cadence
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

```