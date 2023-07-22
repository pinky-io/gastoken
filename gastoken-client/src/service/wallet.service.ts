import { configureChains, createConfig, sepolia } from "wagmi";

import { InjectedConnector } from "wagmi/connectors/injected";
import { publicProvider } from "wagmi/providers/public";

const { chains, publicClient } = configureChains([sepolia], [publicProvider()]);

export const injectedConnector = new InjectedConnector({ chains });

export const config = createConfig({
  autoConnect: true,
  connectors: [
    new InjectedConnector({
      chains,
      options: {
        name: "Injected",
        shimDisconnect: true,
      },
    }),
  ],
  publicClient,
});

export async function getGETHBaseFee(): Promise<number> {
  const formatBaseFeeInGwei = (baseFeeWei: number): number => {
    return baseFeeWei * Math.pow(10, -9);
  };

  try {
    const response = await fetch(
      "https://enormous-silkworm-21.hasura.app/api/rest/get-base-fee-average"
    );
    const jsonData = await response.json();
    return formatBaseFeeInGwei(jsonData.block_aggregate.aggregate.avg.base_fee);
  } catch (error) {
    console.error("Error fetching gETH base fee:", error);
    throw error;
  }
}
