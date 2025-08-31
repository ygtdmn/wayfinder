import { useEffect, useState } from "react";
import { useAccount, useChainId } from "wagmi";
import { useNavigate, Link } from "react-router-dom";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { readContract } from "wagmi/actions";
import type { Address } from "viem";
import { wagmiConfig } from "../lib/wagmi";
import { ierc721CreatorCoreAbi } from "../abis/IERC721CreatorCore-abi";
import { ierc1155CreatorCoreAbi } from "../abis/IERC1155CreatorCore-abi";
import { multiplexAbi } from "../abis/multiplex-abi";
import RegisterExtension from "../components/RegisterExtension";
import RegisterMultiplex from "../components/RegisterMultiplex";
import { useManifoldAuth } from "../hooks/useManifoldAuth";
import { useReadContract } from "wagmi";

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

	const multiplexExtensionAddress = import.meta.env
		.VITE_MULTIPLEX_EXTENSION_ADDRESS as Address;
	const isExtensionRegistered =
		extensions && Array.isArray(extensions)
			? extensions.includes(multiplexExtensionAddress)
			: false;

	// Check if contract is registered with Multiplex
	const { data: isContractRegistered } = useReadContract({
		abi: multiplexAbi,
		address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
		functionName: "isContractOperator",
		args: [
			resolved?.address ||
				("0x0000000000000000000000000000000000000000" as Address),
			multiplexExtensionAddress,
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

			const info: CreatorCoreInfo = {
				address: core,
				type: is721 ? "ERC721" : is1155 ? "ERC1155" : "Unknown",
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
		<div className="min-h-screen">
			<div className="flex justify-between items-center p-8 border-b border-zinc-800">
				<Link to="/" className="text-2xl font-black text-zinc-100">
					multiplex
				</Link>
				<ConnectButton.Custom>
					{({
						account,
						chain,
						openAccountModal,
						openChainModal,
						openConnectModal,
						authenticationStatus,
						mounted,
					}) => {
						const ready = mounted && authenticationStatus !== "loading";
						const connected =
							ready &&
							account &&
							chain &&
							(!authenticationStatus ||
								authenticationStatus === "authenticated");

						return (
							<div
								{...(!ready && {
									"aria-hidden": true,
									style: {
										opacity: 0,
										pointerEvents: "none",
										userSelect: "none",
									},
								})}
							>
								{(() => {
									if (!connected) {
										return (
											<button
												onClick={openConnectModal}
												type="button"
												className="bg-white text-black font-bold px-6 py-3 hover:bg-gray-100 transition-all"
											>
												Connect Wallet
											</button>
										);
									}

									return (
										<div className="flex gap-2">
											<button
												onClick={openChainModal}
												className="bg-white text-black font-bold px-4 py-3 hover:bg-gray-100 transition-all"
												type="button"
											>
												{chain.hasIcon && (
													<div className="inline-block w-4 h-4 mr-2">
														{chain.iconUrl && (
															<img
																alt={chain.name ?? "Chain icon"}
																src={chain.iconUrl}
																className="w-4 h-4"
															/>
														)}
													</div>
												)}
												{chain.name}
											</button>

											<button
												onClick={openAccountModal}
												type="button"
												className="bg-white text-black font-bold px-4 py-3 hover:bg-gray-100 transition-all"
											>
												{account.displayName}
											</button>
										</div>
									);
								})()}
							</div>
						);
					}}
				</ConnectButton.Custom>
			</div>
			<div className="max-w-7xl mx-auto px-8 py-8 space-y-8 animate-fade-in">
				{/* Role Selection */}
				{!userRole && (
					<div>
						<div className="text-center mb-8">
							<h2 className="text-2xl font-display font-bold text-zinc-100">
								Welcome to Multiplex
							</h2>
							<p className="text-zinc-400 mt-2">
								Are you here as a creator or collector?
							</p>
						</div>

						<div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl mx-auto">
							{/* Creator Card */}
							<button
								onClick={() => setUserRole("creator")}
								className="card-hover text-left p-8 group"
							>
								<div className="flex items-center mb-4">
									<div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-lg flex items-center justify-center mr-4 group-hover:bg-opacity-30 transition-all">
										<svg
											className="w-6 h-6 text-blue-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"
											/>
										</svg>
									</div>
									<h3 className="text-xl font-semibold text-zinc-100">
										I'm a Creator
									</h3>
								</div>
								<p className="text-zinc-400 mb-6">
									I want to create new artworks, manage existing tokens, update
									metadata, and control collector permissions.
								</p>
								<div className="space-y-2 text-sm text-zinc-500">
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Mint new artworks
									</div>
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Update metadata & thumbnails
									</div>
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Manage artwork & thumbnail URIs
									</div>
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Set collector permissions
									</div>
								</div>
							</button>

							{/* Collector Card */}
							<button
								onClick={() => setUserRole("collector")}
								className="card-hover text-left p-8 group"
							>
								<div className="flex items-center mb-4">
									<div className="w-12 h-12 bg-purple-500 bg-opacity-20 rounded-lg flex items-center justify-center mr-4 group-hover:bg-opacity-30 transition-all">
										<svg
											className="w-6 h-6 text-purple-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
											/>
										</svg>
									</div>
									<h3 className="text-xl font-semibold text-zinc-100">
										I'm a Collector
									</h3>
								</div>
								<p className="text-zinc-400 mb-6">
									I own tokens and want to customize their display, select
									artworks, or add my own content where allowed.
								</p>
								<div className="space-y-2 text-sm text-zinc-500">
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Change display modes
									</div>
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Select from artist artworks
									</div>
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Choose thumbnails
									</div>
									<div className="flex items-center">
										<svg
											className="w-4 h-4 mr-2 text-green-400"
											fill="none"
											stroke="currentColor"
											viewBox="0 0 24 24"
										>
											<path
												strokeLinecap="round"
												strokeLinejoin="round"
												strokeWidth={2}
												d="M5 13l4 4L19 7"
											/>
										</svg>
										Add artwork (if permitted)
									</div>
								</div>
							</button>
						</div>
					</div>
				)}

				{/* Creator Interface */}
				{userRole === "creator" && (
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
									<h2 className="text-2xl font-display font-bold text-zinc-100">
										Your Collections
									</h2>
									<p className="text-zinc-400 mt-1">
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
													<p className="text-sm font-medium text-zinc-100">
														{c.name || "Unnamed Collection"}
													</p>
													<p className="text-xs text-zinc-400 mt-1">{c.type}</p>
													<p className="text-xs text-zinc-500 truncate mt-1">
														{c.address}
													</p>
												</div>
												{c.type === "ERC721" ? (
													<svg
														className="w-5 h-5 text-zinc-400 ml-2"
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
														className="w-5 h-5 text-zinc-400 ml-2"
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
								<div className="text-center py-8 bg-zinc-800">
									{!address ? (
										<div className="space-y-4">
											<p className="text-zinc-400">
												Connect your wallet to get started
											</p>
										</div>
									) : !isAuthenticated ? (
										<div className="space-y-4">
											<p className="text-zinc-400">
												Sign in to Manifold to discover your collections
												automatically
											</p>
											<button
												onClick={authenticate}
												disabled={isAuthenticating}
												className="btn-primary text-sm"
											>
												{isAuthenticating
													? "Signing..."
													: "Sign in to Manifold"}
											</button>
											<p className="text-sm text-zinc-500">
												Or enter your Creator Core contract address below
											</p>
										</div>
									) : (
										<>
											<p className="text-zinc-400">No collections found.</p>
											<p className="text-sm text-zinc-500 mt-2">
												Enter your Manifold Creator Core contract address below.
											</p>
										</>
									)}
									{!discovering && address && (
										<div className="mt-4 text-xs text-zinc-500">
											<p>
												You can find your collections at{" "}
												<a
													href="https://studio.manifold.xyz"
													target="_blank"
													rel="noopener noreferrer"
													className="text-white underline"
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
									<h3 className="text-lg font-semibold text-zinc-100 mb-4">
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
											<h3 className="text-lg font-semibold text-zinc-100">
												{resolved.name ||
													`${
														resolved.type === "ERC721"
															? "Single Edition"
															: resolved.type === "ERC1155"
															? "Multiple Edition"
															: "Unknown"
													} Collection`}
											</h3>
											<p className="text-sm text-zinc-400 mt-1">
												{resolved.address}
											</p>
										</div>
										<div className="flex flex-col gap-2">
											<div
												className={`px-3 py-1 text-xs font-medium rounded ${
													isExtensionRegistered
														? "bg-success bg-opacity-20 text-success"
														: "bg-zinc-700 text-zinc-400"
												}`}
											>
												Extension: {isExtensionRegistered ? "✓" : "✗"}
											</div>
											<div
												className={`px-3 py-1 text-xs font-medium rounded ${
													isContractRegistered
														? "bg-success bg-opacity-20 text-success"
														: "bg-zinc-700 text-zinc-400"
												}`}
											>
												Multiplex: {isContractRegistered ? "✓" : "✗"}
											</div>
										</div>
									</div>

									{resolved.type !== "Unknown" && (
										<div className="space-y-4">
											<RegisterExtension
												creator={resolved.address}
												type={resolved.type}
											/>
											<RegisterMultiplex creator={resolved.address} />
										</div>
									)}

									{!canProceed && (
										<div className="p-4 bg-yellow-500 bg-opacity-10 border border-yellow-500 border-opacity-30 mb-4">
											<div className="flex items-center gap-2">
												<svg
													className="w-5 h-5 text-yellow-400"
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
												<p className="text-sm text-yellow-300 font-medium">
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
				)}

				{/* Collector Interface */}
				{userRole === "collector" && (
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
									<h2 className="text-2xl font-display font-bold text-zinc-100">
										Collector Zone
									</h2>
									<p className="text-zinc-400 mt-1">
										Enter a collection address to customize tokens you own
									</p>
								</div>
							</div>

							{address ? (
								<div className="space-y-6">
									<div>
										<h3 className="text-lg font-semibold text-zinc-100 mb-4">
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
														<h3 className="text-lg font-semibold text-zinc-100">
															{resolved.name ||
																`${
																	resolved.type === "ERC721"
																		? "Single Edition"
																		: resolved.type === "ERC1155"
																		? "Multiple Edition"
																		: "Unknown"
																} Collection`}
														</h3>
														<p className="text-sm text-zinc-400 mt-1">
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
													<p className="text-sm text-zinc-400 mt-2 text-center">
														Update tokens you own based on artist permissions
													</p>
												</div>
											</div>
										</div>
									)}
								</div>
							) : (
								<div className="text-center py-8 bg-zinc-800 rounded-lg">
									<p className="text-zinc-400">
										Connect your wallet to get started
									</p>
								</div>
							)}
						</div>
					</>
				)}
			</div>
		</div>
	);
}
