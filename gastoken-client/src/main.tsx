import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { WagmiConfig } from "wagmi";
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

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <WagmiConfig config={config}>
      <App />
    </WagmiConfig>
  </React.StrictMode>
);
