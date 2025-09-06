import { useState, useEffect, useMemo } from "react";
import {
	useWriteContract,
	useWaitForTransactionReceipt,
	useReadContract,
} from "wagmi";
import { useSearchParams, useNavigate } from "react-router-dom";
import type { Address } from "viem";
import { wayfinderAbi } from "../abis/wayfinder-abi";
import Header from "../components/Header";
import { useTheme } from "../hooks/useTheme";
import Footer from "../components/Footer";

export default function CollectorZone() {
	const [sp] = useSearchParams();
	const navigate = useNavigate();
	const creator = (sp.get("creator") || "") as Address;

	// Token selection
	const [tokenId, setTokenId] = useState("");

	// Display mode
	const [displayMode, setDisplayMode] = useState(1);

	// URI management for collectors
	const [newArtworkUri, setNewArtworkUri] = useState("");

	// Selection updates
	const [selectedArtworkIndex, setSelectedArtworkIndex] = useState(0);
	const [selectedThumbnailIndex, setSelectedThumbnailIndex] = useState(0);

	// Theme
	const { isDarkMode, toggleTheme } = useTheme();

	// Transaction state
	const { data: hash, isPending, writeContract } = useWriteContract();
	const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
		hash,
	});

	// Read token data from contract
	const {
		data: tokenData,
		error: tokenDataError,
		isLoading: tokenDataLoading,
		refetch: refetchTokenData,
	} = useReadContract({
		abi: wayfinderAbi,
		address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
		functionName: "tokenData",
		args: [creator, BigInt(tokenId || 0)],
		query: { enabled: !!creator && !!tokenId },
	});

	// Read permissions separately
	const { data: permissions } = useReadContract({
		abi: wayfinderAbi,
		address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
		functionName: "getPermissions",
		args: [creator, BigInt(tokenId || 0)],
		query: { enabled: !!creator && !!tokenId },
	});

	// Read artwork data
	const { data: artwork } = useReadContract({
		abi: wayfinderAbi,
		address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
		functionName: "getArtwork",
		args: [creator, BigInt(tokenId || 0)],
		query: { enabled: !!creator && !!tokenId },
	});

	// Read thumbnail info
	const { data: thumbnailInfo } = useReadContract({
		abi: wayfinderAbi,
		address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
		functionName: "getThumbnailInfo",
		args: [creator, BigInt(tokenId || 0)],
		query: { enabled: !!creator && !!tokenId },
	});

	// Read artist artwork URIs
	const { data: artistArtworkUris, refetch: refetchArtworkUris } =
		useReadContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "getArtistArtworkUris",
			args: [creator, BigInt(tokenId || 0)],
			query: { enabled: !!creator && !!tokenId },
		});

	// Read collector artwork URIs
	const { data: collectorArtworkUris, refetch: refetchCollectorUris } =
		useReadContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "getCollectorArtworkUris",
			args: [creator, BigInt(tokenId || 0)],
			query: { enabled: !!creator && !!tokenId },
		});

	// Read artist thumbnail URIs
	const { data: artistThumbnailUris, refetch: refetchThumbnailUris } =
		useReadContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "getThumbnailUris",
			args: [creator, BigInt(tokenId || 0)],
			query: { enabled: !!creator && !!tokenId },
		});

	// Test contract connection with a simple view function
	const { data: htmlTemplate, error: contractError } = useReadContract({
		abi: wayfinderAbi,
		address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
		functionName: "getDefaultHtmlTemplate",
		args: [],
		query: { enabled: true },
	});

	// Initialize data from contract when data loads
	useEffect(() => {
		if (tokenData) {
			setDisplayMode(Number(tokenData[4])); // displayMode
		}
		if (artwork) {
			setSelectedArtworkIndex(Number(artwork.selectedArtistUriIndex));
		}
		if (thumbnailInfo) {
			setSelectedThumbnailIndex(Number(thumbnailInfo[1]));
		}
	}, [tokenData, artwork, thumbnailInfo]);

	// Derived permissions from contract data
	const isOnChainThumbnail = thumbnailInfo ? thumbnailInfo[0] === 0 : true;

	const permissionsData = useMemo(() => {
		const flags = permissions ? Number(permissions.flags) : 0;
		return {
			allowToggleDisplay: (flags & (1 << 10)) !== 0,
			allowSelectArtwork: (flags & (1 << 7)) !== 0,
			allowSelectThumbnail: (flags & (1 << 9)) !== 0,
			allowAddArtwork: (flags & (1 << 8)) !== 0,
			isHtmlMode: displayMode === 1,
		};
	}, [permissions, displayMode]);

	const {
		allowToggleDisplay,
		allowSelectArtwork,
		allowSelectThumbnail,
		allowAddArtwork,
		isHtmlMode,
	} = permissionsData;

	// Debug logging
	useEffect(() => {
		console.log(
			"CollectorZone Debug - Contract Address:",
			import.meta.env.VITE_WAYFINDER_ADDRESS
		);
		console.log("CollectorZone Debug - Creator:", creator);
		console.log("CollectorZone Debug - Token ID:", tokenId);
		console.log("CollectorZone Debug - Token Data:", tokenData);
		console.log(
			"CollectorZone Debug - Contract Connection:",
			htmlTemplate ? "Connected" : "Failed"
		);
		console.log("CollectorZone Debug - Contract Error:", contractError);
	}, [creator, tokenId, tokenData, htmlTemplate, contractError]);

	// Contract interaction functions
	const updateDisplayMode = () => {
		writeContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "setDisplayMode",
			args: [creator, BigInt(tokenId), displayMode],
		});
	};

	const updateArtworkSelection = () => {
		writeContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "setSelectedUri",
			args: [creator, BigInt(tokenId), BigInt(selectedArtworkIndex)],
		});
	};

	const updateThumbnailSelection = () => {
		writeContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "setSelectedThumbnailUri",
			args: [creator, BigInt(tokenId), BigInt(selectedThumbnailIndex)],
		});
	};

	const addCollectorArtworkUri = () => {
		if (!newArtworkUri.trim()) return;
		writeContract({
			abi: wayfinderAbi,
			address: import.meta.env.VITE_WAYFINDER_ADDRESS as Address,
			functionName: "addArtworkUris",
			args: [creator, BigInt(tokenId), [newArtworkUri.trim()]],
		});
		setNewArtworkUri("");
	};

	// Effect to refetch data after successful transactions
	useEffect(() => {
		if (isSuccess) {
			refetchTokenData();
			refetchArtworkUris();
			refetchCollectorUris();
			refetchThumbnailUris();
		}
	}, [
		isSuccess,
		refetchTokenData,
		refetchArtworkUris,
		refetchCollectorUris,
		refetchThumbnailUris,
	]);

	if (!creator) {
		return (
			<div className="text-center py-12">
				<p className={isDarkMode ? "text-zinc-400" : "text-zinc-600"}>
					Please select a collection first.
				</p>
				<button
					onClick={() => navigate("/collections")}
					className="btn-primary mt-4"
				>
					Go to Collections
				</button>
			</div>
		);
	}

	if (isSuccess) {
		return (
			<div className="max-w-2xl mx-auto text-center py-12 animate-fade-in">
				<div className="inline-flex items-center justify-center w-16 h-16 bg-success bg-opacity-10 mb-4">
					<svg
						className="w-8 h-8 text-success"
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
				</div>
				<h2
					className={`text-2xl font-display font-bold ${
						isDarkMode ? "text-zinc-100" : "text-zinc-900"
					} mb-2`}
				>
					Token Updated!
				</h2>
				<p className={`${isDarkMode ? "text-zinc-400" : "text-zinc-600"} mb-8`}>
					Token #{tokenId} has been successfully updated.
				</p>
				<div className="flex gap-3 justify-center">
					<button
						onClick={() => navigate("/collections")}
						className="btn-secondary"
					>
						Back to Collections
					</button>
					<button
						onClick={() => window.location.reload()}
						className="btn-primary"
					>
						Update Another
					</button>
				</div>
			</div>
		);
	}

	return (
		<div
			className={`scroll-smooth min-h-screen flex flex-col ${
				isDarkMode ? "bg-zinc-950 text-zinc-100" : "bg-zinc-50 text-zinc-900"
			}`}
		>
			<Header isDarkMode={isDarkMode} toggleTheme={toggleTheme} />

			{/* Main Content */}
			<div className="flex-grow">
				<div className="px-4 md:px-8 py-8 max-w-6xl mx-auto space-y-6">
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
							} mt-1`}
						>
							Update tokens you own based on artist permissions
						</p>
					</div>

					{/* Token Selection */}
					<div className="card">
						<h3
							className={`text-lg font-semibold ${
								isDarkMode ? "text-zinc-100" : "text-zinc-900"
							} mb-4`}
						>
							Select Your Token
						</h3>
						<div className="space-y-4">
							<div>
								<label className="label">Collection Address</label>
								<p
									className={`text-sm ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									} font-mono`}
								>
									{creator}
								</p>
							</div>
							<div>
								<label className="label">Token ID *</label>
								<input
									className="input-field"
									placeholder="Enter token ID you own"
									value={tokenId}
									onChange={(e) => setTokenId(e.target.value)}
									required
								/>
								<p className="help-text">
									The ID of the token you want to update (must be owned by your
									wallet)
								</p>
							</div>
						</div>

						{tokenData ? (
							<>
								<div
									className={`mt-4 p-4 ${
										isDarkMode
											? "bg-zinc-800"
											: "bg-zinc-100 border border-zinc-300"
									} rounded-lg`}
								>
									<p
										className={`text-sm ${
											isDarkMode ? "text-zinc-300" : "text-zinc-700"
										} mb-3`}
									>
										Your Permissions:
									</p>
									<div className="grid grid-cols-2 gap-4 text-sm">
										<span
											className={`${
												allowToggleDisplay ? "text-green-400" : "text-red-400"
											}`}
										>
											Toggle Display Mode:{" "}
											{allowToggleDisplay ? "Allowed" : "Disabled"}
										</span>
										<span
											className={`${
												allowSelectArtwork ? "text-green-400" : "text-red-400"
											}`}
										>
											Select Artwork:{" "}
											{allowSelectArtwork ? "Allowed" : "Disabled"}
										</span>
										{!isOnChainThumbnail && (
											<span
												className={`${
													allowSelectThumbnail
														? "text-green-400"
														: "text-red-400"
												}`}
											>
												Select Thumbnail:{" "}
												{allowSelectThumbnail ? "Allowed" : "Disabled"}
											</span>
										)}
										<span
											className={`${
												allowAddArtwork ? "text-green-400" : "text-red-400"
											}`}
										>
											Add Artwork: {allowAddArtwork ? "Allowed" : "Disabled"}
										</span>
									</div>
								</div>

								{/* Contract Connection Status */}
								<div
									className={`mt-4 p-3 ${
										isDarkMode
											? "bg-zinc-900"
											: "bg-zinc-50 border border-zinc-300"
									} rounded text-xs`}
								>
									<div className="flex justify-between items-center">
										<span
											className={`${
												isDarkMode ? "text-zinc-400" : "text-zinc-600"
											}`}
										>
											Contract Status:
										</span>
										<span
											className={
												contractError
													? "text-red-400"
													: htmlTemplate
													? "text-green-400"
													: "text-yellow-400"
											}
										>
											{contractError
												? "Connection Failed"
												: htmlTemplate
												? "Connected"
												: "Checking..."}
										</span>
									</div>
								</div>
							</>
						) : null}
					</div>

					{/* Display Mode */}
					{tokenData && allowToggleDisplay ? (
						<div className="card">
							<h3
								className={`text-lg font-semibold ${
									isDarkMode ? "text-zinc-100" : "text-zinc-900"
								} mb-4`}
							>
								Display Mode
							</h3>
							<div className="space-y-4">
								<div>
									<label className="label">Current Display Mode</label>
									<select
										className="input-field"
										value={displayMode}
										onChange={(e) => setDisplayMode(Number(e.target.value))}
									>
										<option value={0}>Image</option>
										<option value={1}>Smart HTML</option>
									</select>
									<p className="help-text">
										Choose how the artwork is displayed by default
									</p>
								</div>
								<button
									type="button"
									onClick={updateDisplayMode}
									className="btn-primary"
									disabled={isPending || isConfirming}
								>
									{isPending || isConfirming
										? "Updating..."
										: "Update Display Mode"}
								</button>
							</div>
						</div>
					) : null}

					{/* Artwork Selection */}
					{tokenData &&
					allowSelectArtwork &&
					!isHtmlMode &&
					artistArtworkUris &&
					Array.isArray(artistArtworkUris) &&
					artistArtworkUris.length > 0 ? (
						<div className="card">
							<h3
								className={`text-lg font-semibold ${
									isDarkMode ? "text-zinc-100" : "text-zinc-900"
								} mb-4`}
							>
								Select Artwork
							</h3>
							<div className="space-y-4">
								<div className="space-y-2">
									<p
										className={`text-sm ${
											isDarkMode ? "text-zinc-400" : "text-zinc-600"
										}`}
									>
										Available artworks from artist:
									</p>
									{artistArtworkUris.map((uri: string, index: number) => (
										<div
											key={index}
											onClick={() => setSelectedArtworkIndex(index)}
											className={`flex gap-2 items-center p-3 rounded cursor-pointer transition-all duration-200 ${
												selectedArtworkIndex === index
													? "bg-blue-600 bg-opacity-20 border-2 border-blue-500 border-opacity-50"
													: isDarkMode
													? "bg-zinc-800 hover:bg-zinc-700 border-2 border-transparent"
													: "bg-zinc-100 hover:bg-zinc-200 border-2 border-transparent"
											}`}
										>
											<div
												className={`w-4 h-4 rounded-full border-2 flex items-center justify-center ${
													selectedArtworkIndex === index
														? "border-blue-400 bg-blue-400"
														: "border-zinc-500"
												}`}
											>
												{selectedArtworkIndex === index && (
													<div className="w-2 h-2 rounded-full bg-white"></div>
												)}
											</div>
											<span className="flex-1 text-sm font-mono ${isDarkMode ? 'text-zinc-300' : 'text-zinc-700'} break-all">
												{index}: {uri}
											</span>
										</div>
									))}
								</div>
								<button
									type="button"
									onClick={updateArtworkSelection}
									className="btn-primary"
									disabled={isPending || isConfirming}
								>
									{isPending || isConfirming
										? "Updating..."
										: "Update Artwork Selection"}
								</button>
							</div>
						</div>
					) : null}

					{/* Thumbnail Selection */}
					{tokenData &&
					allowSelectThumbnail &&
					artistThumbnailUris &&
					Array.isArray(artistThumbnailUris) &&
					artistThumbnailUris.length > 0 ? (
						<div className="card">
							<h3
								className={`text-lg font-semibold ${
									isDarkMode ? "text-zinc-100" : "text-zinc-900"
								} mb-4`}
							>
								Select Thumbnail
							</h3>
							<div className="space-y-4">
								<div className="space-y-2">
									<p
										className={`text-sm ${
											isDarkMode ? "text-zinc-400" : "text-zinc-600"
										}`}
									>
										Available thumbnails from artist:
									</p>
									{artistThumbnailUris.map((uri: string, index: number) => (
										<div
											key={index}
											onClick={() => setSelectedThumbnailIndex(index)}
											className={`flex gap-2 items-center p-3 rounded cursor-pointer transition-all duration-200 ${
												selectedThumbnailIndex === index
													? "bg-blue-600 bg-opacity-20 border-2 border-blue-500 border-opacity-50"
													: isDarkMode
													? "bg-zinc-800 hover:bg-zinc-700 border-2 border-transparent"
													: "bg-zinc-100 hover:bg-zinc-200 border-2 border-transparent"
											}`}
										>
											<div
												className={`w-4 h-4 rounded-full border-2 flex items-center justify-center ${
													selectedThumbnailIndex === index
														? "border-blue-400 bg-blue-400"
														: "border-zinc-500"
												}`}
											>
												{selectedThumbnailIndex === index && (
													<div className="w-2 h-2 rounded-full bg-white"></div>
												)}
											</div>
											<span className="flex-1 text-sm font-mono ${isDarkMode ? 'text-zinc-300' : 'text-zinc-700'} break-all">
												{index}: {uri}
											</span>
										</div>
									))}
								</div>
								<button
									type="button"
									onClick={updateThumbnailSelection}
									className="btn-primary"
									disabled={isPending || isConfirming}
								>
									{isPending || isConfirming
										? "Updating..."
										: "Update Thumbnail Selection"}
								</button>
							</div>
						</div>
					) : null}

					{/* Add Collector Artwork */}
					{tokenData && allowAddArtwork && isHtmlMode ? (
						<div className="card">
							<h3
								className={`text-lg font-semibold ${
									isDarkMode ? "text-zinc-100" : "text-zinc-900"
								} mb-4`}
							>
								Add Your Artwork
							</h3>
							<div className="space-y-4">
								<div className="flex gap-2">
									<input
										className="input-field flex-1"
										placeholder="ipfs://... or https://..."
										value={newArtworkUri}
										onChange={(e) => setNewArtworkUri(e.target.value)}
									/>
									<button
										type="button"
										onClick={addCollectorArtworkUri}
										className="btn-primary"
										disabled={isPending || isConfirming}
									>
										{isPending || isConfirming ? "Adding..." : "Add"}
									</button>
								</div>
								<p className="help-text">
									Add your own artwork URIs (only works in HTML display mode)
								</p>

								{collectorArtworkUris && collectorArtworkUris.length > 0 ? (
									<div className="space-y-2">
										<p
											className={`text-sm ${
												isDarkMode ? "text-zinc-400" : "text-zinc-600"
											}`}
										>
											Your artwork URIs:
										</p>
										{collectorArtworkUris.map((uri: string, index: number) => (
											<div
												key={index}
												className={`flex gap-2 items-center p-2 ${
													isDarkMode
														? "bg-zinc-800"
														: "bg-zinc-100 border border-zinc-300"
												} rounded`}
											>
												<span
													className={`flex-1 text-sm font-mono ${
														isDarkMode ? "text-zinc-300" : "text-zinc-700"
													} break-all`}
												>
													{uri}
												</span>
											</div>
										))}
									</div>
								) : null}
							</div>
						</div>
					) : null}

					{/* Permissions Notice */}
					{tokenData &&
					!allowToggleDisplay &&
					!allowSelectArtwork &&
					(isOnChainThumbnail || !allowSelectThumbnail) &&
					!allowAddArtwork ? (
						<div className="card">
							<div className="flex items-center gap-3">
								<svg
									className="w-6 h-6 ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}"
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
								<div>
									<p className="${isDarkMode ? '${isDarkMode ? 'text-zinc-300' : 'text-zinc-700'}' : 'text-zinc-700'} font-medium">
										No Collector Permissions
									</p>
									<p className="${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'} text-sm">
										This token doesn't allow any collector updates. All settings
										are controlled by the artist.
									</p>
								</div>
							</div>
						</div>
					) : null}

					{/* Status Messages */}
					{hash && !isSuccess && (
						<div className="text-center text-sm ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}">
							Transaction submitted. Waiting for confirmation...
						</div>
					)}

					{/* Loading and Error Messages */}
					{tokenDataLoading && tokenId && (
						<div className="text-center text-sm ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}">
							Loading token data...
						</div>
					)}

					{tokenDataError && tokenId && (
						<div className="card bg-red-500 bg-opacity-10 border-red-500 border-opacity-30">
							<div className="text-center py-6">
								<svg
									className="w-10 h-10 text-red-400 mx-auto mb-3"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										strokeLinecap="round"
										strokeLinejoin="round"
										strokeWidth={2}
										d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
									/>
								</svg>
								<h3 className="text-lg text-red-300 mb-2">
									Error Loading Token Data
								</h3>
								<p className="text-red-200 text-sm mb-4">
									{tokenDataError?.message ||
										"Failed to load token data from contract"}
								</p>
								<div className="space-y-2 text-sm text-red-300">
									<p>
										<strong>Possible reasons:</strong>
									</p>
									<ul className="text-left space-y-1 max-w-md mx-auto">
										<li>• Token #{tokenId} doesn't exist in this collection</li>
										<li>• You don't own this token</li>
										<li>• Contract not deployed or wrong address</li>
										<li>• Network connection issue</li>
									</ul>
								</div>
								<button
									onClick={() => refetchTokenData()}
									className="btn-ghost text-red-300 hover:text-red-200 mt-4"
								>
									Retry Loading
								</button>
							</div>
						</div>
					)}

					{!tokenDataLoading && !tokenDataError && !tokenData && tokenId && (
						<div className="card bg-yellow-500 bg-opacity-10 border-yellow-500 border-opacity-30">
							<div className="text-center py-6">
								<svg
									className="w-10 h-10 text-yellow-400 mx-auto mb-3"
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
								<h3 className="text-lg text-yellow-300 mb-2">
									Token Not Found
								</h3>
								<p className="text-yellow-200 text-sm">
									Token #{tokenId} was not found in this collection or you don't
									own it.
								</p>
							</div>
						</div>
					)}
				</div>
			</div>

			<Footer isDarkMode={isDarkMode} />
		</div>
	);
}
