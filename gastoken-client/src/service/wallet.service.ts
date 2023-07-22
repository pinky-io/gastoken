import { ethers } from 'ethers';

class WalletService {
  private static instance: WalletService;
  private static provider: ethers.BrowserProvider;
  private static signer: ethers.JsonRpcSigner;
  private static gethBaseFee: number;

  private constructor() {
    if (!WalletService.instance) {
      WalletService.instance = this
    }
  }

  public static getInstance(): WalletService {
    if (!WalletService.instance) {
      WalletService.instance = new WalletService();
    }
    return WalletService.instance;
  }

  public static async connectWallet(): Promise<ethers.JsonRpcSigner> {
    this.provider = new ethers.BrowserProvider(window.ethereum);
    this.signer = await this.provider.getSigner();
    return this.signer;
  }

  public static getProvider(): ethers.BrowserProvider {
    return this.provider;
  }

  public static async getGETHBaseFee(): Promise<number> {
    if (this.gethBaseFee) return this.gethBaseFee;

    const formatBaseFeeInGwei = (baseFeeWei: number): number => {
      return baseFeeWei * Math.pow(10, -9);
    }
    try {
      const response = await fetch('https://enormous-silkworm-21.hasura.app/api/rest/get-base-fee-average');
      const jsonData = await response.json();
      this.gethBaseFee = formatBaseFeeInGwei(jsonData.block_aggregate.aggregate.avg.base_fee);
      return this.gethBaseFee;
    } catch (error) {
      console.error('Error fetching gETH base fee:', error);
      throw error;
    }
  }
}

export default WalletService;
