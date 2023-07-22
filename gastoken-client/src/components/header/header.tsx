import { useState } from 'react';
import WalletService from '../../service/wallet.service';
import './header.css';
import { JsonRpcSigner } from 'ethers';
import { useEffect } from 'react';
import WalletComponent from '../wallet/wallet';
import pg95Logo from '../../assets/sp95_icon.png';
import { Link } from 'react-router-dom';

function convertGweiToEth(gwei: number): number {
    const eth = gwei / 10**18;
    return parseFloat(eth.toFixed(4));
}

function formatGETHBaseFee(gETHbaseFeeGwei: number): number {
    return parseFloat(gETHbaseFeeGwei.toFixed(4));
}

const Header = () => {
  const [loading, setLoading]= useState<boolean>(true);
  const [wallet, setWallet] = useState<JsonRpcSigner>();
  const [signerBalance, setSignerBalance] = useState<number>();
  const [gETHBaseFee, setGETHBaseFee] = useState<number>();
  const handleConnectWallet = async () => {
    const userWallet = await WalletService.connectWallet();
    setWallet(userWallet);
  }

  useEffect(() => {
    async function fetchData(): Promise<void> {
        const userWallet = await WalletService.connectWallet();
        setWallet(userWallet);

        const provider = WalletService.getProvider();
        const userBalance = await provider.getBalance(userWallet);
        setSignerBalance(convertGweiToEth(Number(userBalance)));

        const baseFee = await WalletService.getGETHBaseFee();
        setGETHBaseFee(baseFee);
    }
    fetchData().then(() => setLoading(false));
  }, []);

  return (
    <nav className="t-navbar w-4/5 ml-auto mr-auto">
        <Link to="/">
            <img src={pg95Logo} className='h-[50px] w-[50px]'></img>
        </Link>
        { loading ?
            <div role="status">
                <svg aria-hidden="true" className="w-8 h-8 mr-2 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600" viewBox="0 0 100 101" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z" fill="currentColor"/>
                    <path d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z" fill="currentFill"/>
                </svg>
                <span className="sr-only">Loading...</span>
            </div>
            :
            <div className='flex items-center'>
                { gETHBaseFee &&
                    <div className='flex flex-col mr-[12px]'>
                        <p className='text-right text-sm font-light'>⛽ gasETH price</p>
                        <p className='text-right text-sm font-semibold'>{formatGETHBaseFee(gETHBaseFee)}</p>
                    </div>
                }
                <>{ !(wallet && signerBalance)  ? (<button onClick={() => handleConnectWallet()}>Connect wallet</button>) : (<WalletComponent wallet={wallet} walletBalance={signerBalance} />) }</>
                
            </div>
        }
    </nav>
  );
};

export default Header;