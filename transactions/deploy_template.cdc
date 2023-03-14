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