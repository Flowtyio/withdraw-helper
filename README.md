# WithdrawHelper


## Problem

Dapper Wallet offers have an issue with a needed component to accept them. Because they were made
before default implementations were deployed, offers needed a generic way to resolve metadata on
NFTs which were being used to accept them, but the type `@NonFungibleToken.NFT` didn't have a way to do that.

Because of this, currently Dapper Offers contracts take in an interface conformance which **most** collections
adhere to. That confromance is `@AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver}`. These two interfaces
give Dapper all the things it needs to resolve data (`MetadataViews.Resolver`) while still ensuring that the resource 
is an NFT (`NonFungibleToken.INFT`).

The problem, however, is that withdrawing an NFT using the `NonFungibleToken.Provider` interface doesn't adhere to this conformance
pattern. Instead, you must cast to the actual NFT type that you are withdrawing, and it will adhere to both the needed interfaces 
to be used for offer acceptance.

```cadence
// imports...

transaction(nftId: UInt64, offerId: UInt64, DapperOfferAddress: Address, storagePathIdentifier: String) {
    let dapperOffer: &DapperOffersV2.DapperOffer{DapperOffersV2.DapperOfferPublic}
    let offer: &OffersV2.Offer{OffersV2.OfferPublic}
    let receiverCapability: Capability<&{FungibleToken.Receiver}>
    prepare(signer: AuthAccount) {
        // Get the DapperOffers resource
        self.dapperOffer = getAccount(DapperOfferAddress)
            .getCapability<&DapperOffersV2.DapperOffer{DapperOffersV2.DapperOfferPublic}>(
                DapperOffersV2.DapperOffersPublicPath
            ).borrow()
            ?? panic("Could not borrow DapperOffer from provided address")
        // Set the fungible token receiver capabillity
        self.receiverCapability = signer.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.receiverCapability.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin receiver")
        // Get the DapperOffer details
        self.offer = self.dapperOffer.borrowOffer(offerId: offerId)
            ?? panic("No Offer with that ID in DapperOffer")

        // Get the NFT ressource and widthdraw the NFT from the signers account
        let nftCollection = signer.borrow<&{NonFungibleToken.Provider}>(from: StoragePath(identifier: storagePathIdentifier)!)
            ?? panic("Cannot borrow NFT collection receiver from account")

        // ----------------------- THIS PIECE IS WHAT MATTERS ------------------------------------
        // we have to cast the nft when withdrawing it because DapperOffersV2 expects a resource
        // which matches @AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver} which these casted examples
        // all follow.
        let nft  <- nftCollection.withdraw(withdrawID: nftId) as! @ExampleNFT.NFT // <- THIS PART CHANGES WITH EACH NFT TYPE
        self.offer.accept(
            item: <-nft,
            receiverCapability: self.receiverCapability
        )
        // ---------------------------------------------------------------------------------------
    }
    execute {
        // delete the offer
        self.dapperOffer.cleanup(offerId: offerId)
    }
}
```

## Solution

This repo contains a contract that deploys other contracts. It exposes n resource interface which can take a `NonFungibleToken.Provider`
capability, and return an `@AnyResource{NonFungibleToken.NFT, MetadataViews.Resolver}`. It will do this 
by generating a contract which imports the type we want a template for which does the casting for us, enabling a transaction to give
a capability and nft id, and a resource with the proper conformance will come back.

Below is an example generated contract for ExampleNFT. Note that it implements `WithdrawHelper.Withdrawer` and has a method which 
will return the correct conformance, but it knows specific details about the kind of NFT it will be withdrawing and does the casting for us.

```cadence
import WithdrawHelper from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7
import ExampleNFT from 0xf8d6e0586b0a20c7

pub contract ExampleNFT0xf8d6e0586b0a20c7WithdrawHelper {
   pub let PublicPath: PublicPath
   pub let StoragePath: StoragePath

   pub resource Withdrawer: WithdrawHelper.Withdrawer {
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
       let helper <- create Withdrawer()
       let identifier = WithdrawHelper.getPathIdentifier(helper.nftType)
       self.PublicPath = PublicPath(identifier: identifier)!
       self.StoragePath = StoragePath(identifier: identifier)!

       self.account.save(<-helper, to: self.StoragePath)
       self.account.link<&{WithdrawHelper.Withdrawer}>(self.PublicPath, target: self.StoragePath)
   }
}

```

## Examples

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