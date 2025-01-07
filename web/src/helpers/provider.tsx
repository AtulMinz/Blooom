"use client";
import { WagmiProvider, createConfig, http } from "wagmi";
// import { mainnet } from "wagmi/chains";
import { chains } from "@lens-network/sdk/viem";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider, getDefaultConfig } from "connectkit";
import React from "react";

const config = createConfig(
  getDefaultConfig({
    // Your dApps chains
    chains: [chains.testnet],
    transports: {
      // RPC URL for each chain
      [chains.testnet.id]: http(
        `https://rpc.testnet.lens.dev
`
      ),
    },

    // Required API Keys
    walletConnectProjectId: process.env
      .NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID as string,

    // Required App Info
    appName: "Bluum",

    // Optional App Info
    appDescription: "Bloom your habit",
    appUrl: "https://family.co", // your app's url
    appIcon:
      "https://cdn.dribbble.com/userupload/9882298/file/original-aa6dacc892542f681edac1fa3d559994.jpg?resize=1200x900&vertical=center", // your app's icon, no bigger than 1024x1024px (max. 1MB)
  })
);

const queryClient = new QueryClient();

export const Web3Provider = ({
  children,
}: Readonly<{ children: React.ReactNode }>) => {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ConnectKitProvider>{children}</ConnectKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
};
