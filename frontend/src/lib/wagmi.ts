import { http } from "wagmi";
import { sepolia } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

export const chains = [sepolia] as const;

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID as
	| string
	| undefined;

export const wagmiConfig = getDefaultConfig({
	appName: "Multiplex Frontend",
	projectId: projectId ?? "",
	chains,
	transports: {
		[sepolia.id]: http(),
	},
	ssr: false,
});

// Declaration merging for better type inference across the app
declare module 'wagmi' {
  interface Register {
    config: typeof wagmiConfig
  }
}
