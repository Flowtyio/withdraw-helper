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