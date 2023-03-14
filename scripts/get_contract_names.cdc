pub fun main(addr: Address):[String] {
  return getAccount(addr).contracts.names
}
