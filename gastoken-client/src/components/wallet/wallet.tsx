import { JsonRpcSigner } from "ethers";

interface IWallet {
    wallet: JsonRpcSigner;
    walletBalance: number;
}

const formatAddress = (address: string): string => {
    return address.substring(0, 5) + "..." + address.slice(-3);
}

const WalletComponent = (props: IWallet) => {
  return (
    <div className="rounded-xl bg-white h-[36px] flex items-center text-black p-[3px]">
        <p className="h-full flex items-center font-semibold mx-[6px]">{ props.walletBalance } ETH</p>
        <p className="h-full flex items-center font-semibold bg-slate-200 rounded-xl px-[4px]">{ formatAddress(props.wallet.address) }</p>
    </div>
  );
};

export default WalletComponent;