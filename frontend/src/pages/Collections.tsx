import { useEffect, useState } from "react";
import { useAccount, useChainId } from "wagmi";
import { useNavigate } from "react-router-dom";
import { readContract } from "wagmi/actions";
import type { Address } from "viem";
import { wagmiConfig } from "../lib/wagmi";
import { ierc721CreatorCoreAbi } from "../abis/IERC721CreatorCore-abi";
import { ierc1155CreatorCoreAbi } from "../abis/IERC1155CreatorCore-abi";
import { wayfinderAbi } from "../abis/wayfinder-abi";
import RegisterExtension from "../components/RegisterExtension";
import RegisterWayfinder from "../components/RegisterWayfinder";
import { useManifoldAuth } from "../hooks/useManifoldAuth";
import { useReadContract } from "wagmi";
import { Palette, Heart } from "lucide-react";
import Header from "../components/Header";
import ConnectButtonPrimary from "../components/ConnectButtonPrimary";
import { useTheme } from "../hooks/useTheme";
import Footer from "../components/Footer";

type CreatorCoreInfo = {
	address: Address;
	type: "ERC721" | "ERC1155" | "Unknown";
	name?: string;
	isAdmin: boolean | null;
};

export default function Collections() {
	const { address } = useAccount();
	const navigate = useNavigate();
	const chainId = useChainId();
	const { token, session, isAuthenticated, isAuthenticating, authenticate } =
		useManifoldAuth();
	const [creatorInput, setCreatorInput] = useState("");
	const [resolved, setResolved] = useState<CreatorCoreInfo | null>(null);
	const [checking, setChecking] = useState(false);
	const [discovering, setDiscovering] = useState(false);
	const [discovered, setDiscovered] = useState<CreatorCoreInfo[]>([]);
	const [userRole, setUserRole] = useState<"creator" | "collector" | null>(
		null
	);
	const [authError, setAuthError] = useState<string | null>(null);
	const { isDarkMode, toggleTheme } = useTheme();

	// Check if extension is registered with Manifold
	const coreAbi =
		resolved?.type === "ERC721"
			? ierc721CreatorCoreAbi
			: ierc1155CreatorCoreAbi;
	const { data: extensions } = useReadContract({
		abi: coreAbi,
		address: resolved?.address,
		functionName: "getExtensions",
		args: [],
		query: { enabled: !!resolved?.address && resolved?.type !== "Unknown" },
	});

	const wayfinderExtensionAddress = import.meta.env
		.VITE_WAYFINDER_EXTENSION_ADDRESS as Address;
	const isExtensionRegistered =
		extensions && Array.isArray(extensions)
			? extensions.includes(wayfinderExtensionAddress)
			: false;

	// Check if contract is registered with Wayfinder
	const { data: isContractRegistered } = useReadContract({
		abi: wayfinderAbi,
		address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
		functionName: "isContractOperator",
		args: [
			resolved?.address ||
				("0x0000000000000000000000000000000000000000" as Address),
			wayfinderExtensionAddress,
		],
		query: { enabled: !!resolved?.address },
	});

	const canProceed = Boolean(
		resolved &&
			resolved.isAdmin &&
			isExtensionRegistered &&
			isContractRegistered
	);

	useEffect(() => {
		setResolved(null);
	}, [creatorInput]);

	// Clear discovered collections when wallet address changes
	useEffect(() => {
		setDiscovered([]);
		setResolved(null);
		setAuthError(null);
	}, [address]);

	const checkCreator = async () => {
		if (!address) return;
		try {
			setChecking(true);
			const core = creatorInput.trim() as Address;

			const is721 = await readContract(wagmiConfig, {
				address: core,
				abi: ierc721CreatorCoreAbi,
				functionName: "supportsInterface",
				args: ["0x80ac58cd" as `0x${string}`],
			}).catch(() => false);

			const is1155 = await readContract(wagmiConfig, {
				address: core,
				abi: ierc1155CreatorCoreAbi,
				functionName: "supportsInterface",
				args: ["0xd9b67a26" as `0x${string}`],
			}).catch(() => false);

			// Skip admin check for now as requested
			const isAdmin = true; // await readContract(wagmiConfig, {
			//   address: core,
			//   abi: (IAdminControl as any).abi,
			//   functionName: 'isAdmin',
			//   args: [address],
			// }).catch(() => null)

			// Fetch contract name using standard ERC721/ERC1155 name function
			let contractName: string | undefined;
			try {
				const nameAbi = [
					{
						type: "function",
						name: "name",
						inputs: [],
						outputs: [{ name: "", type: "string", internalType: "string" }],
						stateMutability: "view",
					},
				] as const;

				if (is721 || is1155) {
					contractName = await readContract(wagmiConfig, {
						address: core,
						abi: nameAbi,
						functionName: "name",
						args: [],
					});
				}
			} catch (error) {
				console.log("Could not fetch contract name:", error);
			}

			const info: CreatorCoreInfo = {
				address: core,
				type: is721 ? "ERC721" : is1155 ? "ERC1155" : "Unknown",
				name: contractName,
				isAdmin: isAdmin,
			};
			setResolved(info);
		} finally {
			setChecking(false);
		}
	};

	const discoverCreatorCores = async () => {
		if (!address || !token || !session) return;
		try {
			setDiscovering(true);

			console.log("Discovering creator cores via Manifold API");

			// Fetch all creator cores from Manifold API
			const response = await fetch(
				"https://studio.api.manifoldxyz.dev/contract_deployer/creator-core/all",
				{
					headers: {
						Authorization: `Bearer ${token}`,
						Accept: "application/json",
						Session: session,
					},
				}
			);

			if (!response.ok) {
				throw new Error(`Manifold API error: ${response.status}`);
			}

			const allContracts = await response.json();
			console.log(`Found ${allContracts.length} total creator cores`);

			// Map chainId to networkId
			const chainIdToNetworkId: Record<number, number> = {
				1: 1, // Mainnet
				5: 5, // Goerli
				137: 137, // Polygon
				8453: 8453, // Base
				11155111: 11155111, // Sepolia
			};

			const networkId = chainIdToNetworkId[chainId];
			if (!networkId) {
				console.log("Unsupported network for discovery");
				setDiscovered([]);
				return;
			}

			// Filter contracts for current network
			interface ContractInfo {
				networkId: number;
				status: string;
				contractAddress: string;
			}
			interface Contract {
				contractInfo: ContractInfo[];
				spec: string;
				name: string;
			}
			const contractsOnNetwork = allContracts
				.filter((contract: Contract) =>
					contract.contractInfo.some(
						(info: ContractInfo) =>
							info.networkId === networkId && info.status === "deploy-complete"
					)
				)
				.map((contract: Contract) => {
					const info = contract.contractInfo.find(
						(info: ContractInfo) => info.networkId === networkId
					);
					return {
						address: info?.contractAddress as Address,
						spec: contract.spec,
						name: contract.name,
					};
				});

			console.log(
				`Found ${contractsOnNetwork.length} contracts on current network`
			);

			// Skip admin check for now, just return all contracts
			interface NetworkContract {
				address: Address;
				spec: string;
				name: string;
			}
			const results: CreatorCoreInfo[] = contractsOnNetwork.map(
				(contract: NetworkContract) => ({
					address: contract.address,
					type: contract.spec as "ERC721" | "ERC1155",
					name: contract.name,
					isAdmin: true, // Skip admin check for now
				})
			);

			console.log(`Found ${results.length} contracts`);
			setDiscovered(results);
		} catch (error) {
			console.error("Discovery error:", error);
		} finally {
			setDiscovering(false);
		}
	};

	useEffect(() => {
		// Automatically discover creator cores when authenticated
		if (address && isAuthenticated) {
			void discoverCreatorCores();
		}
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [address, chainId, isAuthenticated]);

	return (
		<div
			className={`scroll-smooth min-h-screen flex flex-col ${
				isDarkMode ? "bg-zinc-950 text-zinc-100" : "bg-zinc-50 text-zinc-900"
			}`}
		>
			<Header isDarkMode={isDarkMode} toggleTheme={toggleTheme} />

			{/* Role Selection - Centered */}
			{!userRole && (
				<div className="flex-grow flex items-center justify-center p-4">
					<div className="max-w-6xl w-full">
						<div className="px-4 md:px-8 py-8">
							<div>
								<div className="text-center mb-8">
									<h1
										className={`text-3xl md:text-4xl lg:text-5xl font-bold tracking-tight mb-4 md:mb-6 ${
											isDarkMode ? "text-zinc-100" : "text-zinc-900"
										}`}
									>
										Welcome to Wayfinder
									</h1>
									<p
										className={`text-sm md:text-base lg:text-lg font-medium ${
											isDarkMode ? "text-zinc-300" : "text-zinc-600"
										}`}
									>
										Are you here as a creator or collector?
									</p>
								</div>

								<div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-3xl mx-auto">
									{/* Creator Card */}
									<button
										onClick={() => setUserRole("creator")}
										className="card-hover p-12 group aspect-square flex flex-col justify-center"
									>
										<div className="text-center">
											<div className="w-16 h-16 bg-orange-500 bg-opacity-20 rounded-xl flex items-center justify-center mx-auto mb-6 group-hover:bg-opacity-30 transition-all">
												<Palette className="w-8 h-8 text-orange-400" />
											</div>
											<h3
												className={`text-2xl font-bold ${
													isDarkMode ? "text-white" : "text-zinc-900"
												} mb-4`}
											>
												Creator
											</h3>
											<p
												className={`${
													isDarkMode ? "text-zinc-300" : "text-zinc-600"
												} text-md leading-relaxed`}
											>
												Create and manage your tokens with full control over
												metadata and collector permissions.
											</p>
										</div>
									</button>

									{/* Collector Card */}
									<button
										onClick={() => setUserRole("collector")}
										className="card-hover p-12 group aspect-square flex flex-col justify-center"
									>
										<div className="text-center">
											<div className="w-16 h-16 bg-purple-500 bg-opacity-20 rounded-xl flex items-center justify-center mx-auto mb-6 group-hover:bg-opacity-30 transition-all">
												<Heart className="w-8 h-8 text-purple-400" />
											</div>
											<h3
												className={`text-2xl font-bold ${
													isDarkMode ? "text-white" : "text-zinc-900"
												} mb-4`}
											>
												Collector
											</h3>
											<p
												className={`${
													isDarkMode ? "text-zinc-300" : "text-zinc-600"
												} text-md leading-relaxed`}
											>
												Customize and personalize the tokens you own based on
												artist-defined permissions.
											</p>
										</div>
									</button>
								</div>
							</div>
						</div>
					</div>
				</div>
			)}

			{/* Main Content for Creator and Collector */}
			<div className="flex-grow">
				{/* Creator Interface - Normal Layout */}
				{userRole === "creator" && (
					<div className="px-4 md:px-8 py-8 max-w-6xl mx-auto space-y-6">
						<>
							<div className="flex items-center gap-4 mb-6">
								<button
									onClick={() => setUserRole(null)}
									className="btn-ghost text-sm"
								>
									← Back to role selection
								</button>
							</div>

							<div>
								<div className="flex items-center justify-between mb-6">
									<div>
										<h2
											className={`text-lg md:text-xl font-bold ${
												isDarkMode ? "text-zinc-100" : "text-zinc-900"
											}`}
										>
											Your Collections
										</h2>
										<p
											className={`text-sm md:text-base ${
												isDarkMode ? "text-zinc-300" : "text-zinc-600"
											}`}
										>
											Select a collection to manage or paste an address below
										</p>
									</div>
									{isAuthenticated && (
										<button
											onClick={discoverCreatorCores}
											disabled={discovering}
											className="btn-ghost"
										>
											{discovering ? (
												<>
													<svg
														className="animate-spin -ml-1 mr-2 h-4 w-4 text-zinc-400 inline"
														fill="none"
														viewBox="0 0 24 24"
													>
														<circle
															className="opacity-25"
															cx="12"
															cy="12"
															r="10"
															stroke="currentColor"
															strokeWidth="4"
														></circle>
														<path
															className="opacity-75"
															fill="currentColor"
															d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
														></path>
													</svg>
													Searching...
												</>
											) : (
												"Refresh"
											)}
										</button>
									)}
								</div>

								{discovered.length > 0 ? (
									<div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
										{discovered.map((c) => (
											<button
												key={c.address}
												className="card-hover text-left"
												onClick={() => setResolved(c)}
											>
												<div className="flex items-start justify-between">
													<div className="flex-1 min-w-0">
														<p
															className={`text-sm font-medium ${
																isDarkMode ? "text-zinc-100" : "text-zinc-900"
															}`}
														>
															{c.name || "Unnamed Collection"}
														</p>
														<p
															className={`text-xs ${
																isDarkMode ? "text-zinc-400" : "text-zinc-600"
															} mt-1`}
														>
															{c.type}
														</p>
														<p
															className={`text-xs ${
																isDarkMode ? "text-zinc-500" : "text-zinc-500"
															} truncate mt-1`}
														>
															{c.address}
														</p>
													</div>
													{c.type === "ERC721" ? (
														<svg
															className={`w-5 h-5 ${
																isDarkMode ? "text-zinc-400" : "text-zinc-600"
															} ml-2`}
															fill="none"
															stroke="currentColor"
															viewBox="0 0 24 24"
														>
															<path
																strokeLinecap="round"
																strokeLinejoin="round"
																strokeWidth={2}
																d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"
															/>
														</svg>
													) : (
														<svg
															className={`w-5 h-5 ${
																isDarkMode ? "text-zinc-400" : "text-zinc-600"
															} ml-2`}
															fill="none"
															stroke="currentColor"
															viewBox="0 0 24 24"
														>
															<path
																strokeLinecap="round"
																strokeLinejoin="round"
																strokeWidth={2}
																d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
															/>
														</svg>
													)}
												</div>
											</button>
										))}
									</div>
								) : (
									<div
										className={`text-center py-8 ${
											isDarkMode
												? "bg-zinc-800"
												: "bg-white border border-zinc-300"
										}`}
									>
										{!address ? (
											<div className="space-y-4">
												<p
													className={
														isDarkMode ? "text-zinc-400" : "text-zinc-600"
													}
												>
													Connect your wallet to get started
												</p>
												<div className="flex justify-center">
													<ConnectButtonPrimary />
												</div>
											</div>
										) : !isAuthenticated ? (
											<div className="space-y-4">
												<p
													className={
														isDarkMode ? "text-zinc-400" : "text-zinc-600"
													}
												>
													Sign in to Manifold to discover your collections
													automatically
												</p>
												<button
													onClick={async () => {
														try {
															setAuthError(null);
															await authenticate();
														} catch (error) {
															setAuthError(error instanceof Error ? error.message : 'Authentication failed');
														}
													}}
													disabled={isAuthenticating}
													className="btn-primary text-sm"
												>
													{isAuthenticating
														? "Signing..."
														: "Sign in to Manifold"}
												</button>
												{authError && (
													<div className={`mt-4 p-3 rounded-lg border ${
														isDarkMode 
															? "bg-red-900 bg-opacity-20 border-red-500 border-opacity-30" 
															: "bg-red-50 border-red-300"
													}`}>
														<p className={`text-sm ${
															isDarkMode ? "text-red-300" : "text-red-800"
														}`}>
															{authError}
														</p>
														{authError.includes("not registered") && (
															<a 
																href="https://studio.manifold.xyz" 
																target="_blank" 
																rel="noopener noreferrer"
																className={`text-sm underline mt-2 inline-block ${
																	isDarkMode ? "text-red-200" : "text-red-600"
																}`}
															>
																Register at studio.manifold.xyz →
															</a>
														)}
													</div>
												)}
												<p
													className={`text-sm ${
														isDarkMode ? "text-zinc-500" : "text-zinc-500"
													}`}
												>
													Or enter your Creator Core contract address below
												</p>
											</div>
										) : (
											<>
												<p
													className={
														isDarkMode ? "text-zinc-400" : "text-zinc-600"
													}
												>
													No collections found.
												</p>
												<p
													className={`text-sm ${
														isDarkMode ? "text-zinc-500" : "text-zinc-500"
													} mt-2`}
												>
													Enter your Manifold Creator Core contract address
													below.
												</p>
											</>
										)}
										{!discovering && address && (
											<div
												className={`mt-4 text-xs ${
													isDarkMode ? "text-zinc-500" : "text-zinc-500"
												}`}
											>
												<p>
													You can find your collections at{" "}
													<a
														href="https://studio.manifold.xyz"
														target="_blank"
														rel="noopener noreferrer"
														className={
															isDarkMode
																? "text-white underline"
																: "text-zinc-900 underline"
														}
													>
														studio.manifold.xyz
													</a>
												</p>
											</div>
										)}
									</div>
								)}
							</div>

							{address && (
								<>
									<div className="divider"></div>

									<div>
										<h3
											className={`text-lg md:text-xl font-bold ${
												isDarkMode ? "text-zinc-100" : "text-zinc-900"
											} mb-4`}
										>
											Or enter a collection address
										</h3>
										<div className="flex gap-3">
											<input
												className="input-field flex-1"
												value={creatorInput}
												onChange={(e) => setCreatorInput(e.target.value)}
												placeholder="0x... collection address"
											/>
											<button
												className="btn-primary"
												onClick={checkCreator}
												disabled={!creatorInput || checking}
											>
												{checking ? "Checking..." : "Check"}
											</button>
										</div>
									</div>
								</>
							)}

							{resolved && (
								<div className="card animate-slide-up">
									<div className="space-y-4">
										<div className="flex items-center justify-between">
											<div>
												<h3
													className={`text-lg font-semibold ${
														isDarkMode ? "text-zinc-100" : "text-zinc-900"
													}`}
												>
													{resolved.name ||
														`${
															resolved.type === "ERC721"
																? "Single Edition"
																: resolved.type === "ERC1155"
																? "Multiple Edition"
																: "Unknown"
														} Collection`}
												</h3>
												<p
													className={`text-sm ${
														isDarkMode ? "text-zinc-400" : "text-zinc-600"
													} mt-1`}
												>
													{resolved.address}
												</p>
											</div>
											<div className="flex flex-col gap-2">
												<div
													className={`px-3 py-1 text-xs font-medium rounded ${
														isExtensionRegistered
															? "bg-success bg-opacity-20 text-success"
															: isDarkMode
															? "bg-zinc-700 text-zinc-400"
															: "bg-zinc-200 text-zinc-600"
													}`}
												>
													Extension: {isExtensionRegistered ? "✓" : "✗"}
												</div>
												<div
													className={`px-3 py-1 text-xs font-medium rounded ${
														isContractRegistered
															? "bg-success bg-opacity-20 text-success"
															: isDarkMode
															? "bg-zinc-700 text-zinc-400"
															: "bg-zinc-200 text-zinc-600"
													}`}
												>
													Wayfinder: {isContractRegistered ? "✓" : "✗"}
												</div>
											</div>
										</div>

										{resolved.type !== "Unknown" && (
											<div className="space-y-4">
												<RegisterExtension
													creator={resolved.address}
													type={resolved.type}
												/>
												<RegisterWayfinder creator={resolved.address} />
											</div>
										)}

										{!canProceed && (
											<div
												className={`p-4 mb-4 border ${
													isDarkMode
														? "bg-yellow-500 bg-opacity-10 border-yellow-500 border-opacity-30"
														: "bg-yellow-50 border-yellow-300"
												}`}
											>
												<div className="flex items-center gap-2">
													<svg
														className={`w-5 h-5 ${
															isDarkMode ? "text-yellow-400" : "text-yellow-600"
														}`}
														fill="none"
														stroke="currentColor"
														viewBox="0 0 24 24"
													>
														<path
															strokeLinecap="round"
															strokeLinejoin="round"
															strokeWidth={2}
															d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
														/>
													</svg>
													<p
														className={`text-sm font-medium ${
															isDarkMode ? "text-yellow-300" : "text-yellow-800"
														}`}
													>
														Complete both registration steps above to enable
														minting and updating
													</p>
												</div>
											</div>
										)}

										<div className="flex gap-3 pt-4">
											<button
												className={`flex-1 ${
													canProceed
														? "btn-primary"
														: "btn-primary opacity-50 cursor-not-allowed"
												}`}
												disabled={!canProceed}
												onClick={() =>
													navigate(
														`/mint?creator=${resolved.address}&type=${resolved.type}`
													)
												}
											>
												Create New Artwork
											</button>
											<button
												className={`flex-1 ${
													canProceed
														? "btn-secondary"
														: "btn-secondary opacity-50 cursor-not-allowed"
												}`}
												disabled={!canProceed}
												onClick={() =>
													navigate(
														`/update?creator=${resolved.address}&type=${resolved.type}`
													)
												}
											>
												Update Existing
											</button>
										</div>
									</div>
								</div>
							)}
						</>
					</div>
				)}

				{/* Collector Interface - Normal Layout */}
				{userRole === "collector" && (
					<div className="px-4 md:px-8 py-8 max-w-6xl mx-auto space-y-6">
						<>
							<div className="flex items-center gap-4 mb-6">
								<button
									onClick={() => setUserRole(null)}
									className="btn-ghost text-sm"
								>
									← Back to role selection
								</button>
							</div>

							<div>
								<div className="flex items-center justify-between mb-6">
									<div>
										<h2
											className={`text-lg md:text-xl font-bold ${
												isDarkMode ? "text-zinc-100" : "text-zinc-900"
											}`}
										>
											Collector Zone
										</h2>
										<p
											className={`text-sm md:text-base ${
												isDarkMode ? "text-zinc-300" : "text-zinc-600"
											}`}
										>
											Enter a collection address to customize tokens you own
										</p>
									</div>
								</div>

								{address ? (
									<div className="space-y-6">
										<div>
											<h3
												className={`text-lg md:text-xl font-bold ${
													isDarkMode ? "text-zinc-100" : "text-zinc-900"
												} mb-4`}
											>
												Enter Collection Address
											</h3>
											<div className="flex gap-3">
												<input
													className="input-field flex-1"
													value={creatorInput}
													onChange={(e) => setCreatorInput(e.target.value)}
													placeholder="0x... collection address"
												/>
												<button
													className="btn-primary"
													onClick={checkCreator}
													disabled={!creatorInput || checking}
												>
													{checking ? "Checking..." : "Check"}
												</button>
											</div>
										</div>

										{resolved && (
											<div className="card animate-slide-up">
												<div className="space-y-4">
													<div className="flex items-center justify-between">
														<div>
															<h3
																className={`text-lg font-semibold ${
																	isDarkMode ? "text-zinc-100" : "text-zinc-900"
																}`}
															>
																{resolved.name ||
																	`${
																		resolved.type === "ERC721"
																			? "Single Edition"
																			: resolved.type === "ERC1155"
																			? "Multiple Edition"
																			: "Unknown"
																	} Collection`}
															</h3>
															<p
																className={`text-sm ${
																	isDarkMode ? "text-zinc-400" : "text-zinc-600"
																} mt-1`}
															>
																{resolved.address}
															</p>
														</div>
														<div className="px-3 py-1 text-sm font-medium bg-success bg-opacity-20 text-success">
															Ready for Collectors
														</div>
													</div>

													<div className="pt-4">
														<button
															className="btn-primary w-full"
															onClick={() =>
																navigate(
																	`/collector-zone?creator=${resolved.address}&type=${resolved.type}`
																)
															}
														>
															Enter Collector Zone
														</button>
														<p
															className={`text-sm ${
																isDarkMode ? "text-zinc-400" : "text-zinc-600"
															} mt-2 text-center`}
														>
															Update tokens you own based on artist permissions
														</p>
													</div>
												</div>
											</div>
										)}
									</div>
								) : (
									<div
										className={`text-center py-8 rounded-lg space-y-4 ${
											isDarkMode
												? "bg-zinc-800"
												: "bg-white border border-zinc-300"
										}`}
									>
										<p
											className={isDarkMode ? "text-zinc-400" : "text-zinc-600"}
										>
											Connect your wallet to get started
										</p>
										<div className="flex justify-center">
											<ConnectButtonPrimary />
										</div>
									</div>
								)}
							</div>
						</>
					</div>
				)}
			</div>

			<Footer isDarkMode={isDarkMode} />
		</div>
	);
}
