import WithdrawHelper from 0xcf2a12e6d2cc212b
import StringUtils from 0xcf2a12e6d2cc212b

// A.d9c02cdacccb25ab.FlowtyTestNFT.NFT

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