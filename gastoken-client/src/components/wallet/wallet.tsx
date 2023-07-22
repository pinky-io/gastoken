interface IWallet {
  address: string;
  walletBalance: string;
}

const formatAddress = (address: string): string => {
  return address.substring(0, 5) + "..." + address.slice(-3);
};

const formatWalletBalance = (walletBalance: string): string => {
  return Number(walletBalance).toFixed(4).toString();
};

const WalletComponent = ({ address, walletBalance }: IWallet) => {
  return (
    <div className="rounded-xl bg-white h-[36px] flex items-center text-black p-[3px]">
      <p className="h-full flex items-center font-semibold mx-[6px]">
        {formatWalletBalance(walletBalance)} ETH
      </p>
      <p className="h-full flex items-center font-semibold bg-slate-200 rounded-xl px-[4px]">
        {formatAddress(address)}
      </p>
    </div>
  );
};

export default WalletComponent;
