import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import "@rainbow-me/rainbowkit/styles.css";
import { RainbowKitProvider, darkTheme, lightTheme } from "@rainbow-me/rainbowkit";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { wagmiConfig, chains } from "./lib/wagmi";

const queryClient = new QueryClient();

// Dynamic RainbowKit theme to support light/dark modes
const customTheme = {
	lightMode: lightTheme({
		accentColor: '#000000', // Black in light mode
		accentColorForeground: '#ffffff',
		borderRadius: 'none',
		fontStack: 'system',
	}),
	darkMode: darkTheme({
		accentColor: '#ffffff', // White in dark mode  
		accentColorForeground: '#000000',
		borderRadius: 'none',
		fontStack: 'system',
	}),
};

createRoot(document.getElementById("root")!).render(
	<StrictMode>
		<WagmiProvider config={wagmiConfig}>
			<QueryClientProvider client={queryClient}>
				<RainbowKitProvider 
					initialChain={chains[0]}
					theme={customTheme}
				>
					<App />
				</RainbowKitProvider>
			</QueryClientProvider>
		</WagmiProvider>
	</StrictMode>
);
