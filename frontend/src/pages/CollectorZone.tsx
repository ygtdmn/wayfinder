import { useState, useEffect, useMemo } from "react";
import {
	useWriteContract,
	useWaitForTransactionReceipt,
	useReadContract,
} from "wagmi";
import { useSearchParams, useNavigate, Link } from "react-router-dom";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import type { Address } from "viem";
import { multiplexAbi } from "../abis/multiplex-abi";

export default function CollectorZone() {
	const [sp] = useSearchParams();
	const navigate = useNavigate();
	const creator = (sp.get("creator") || "") as Address;

	// Token selection
	const [tokenId, setTokenId] = useState("");

	// Display mode
	const [displayMode, setDisplayMode] = useState(1);

	// URI management for collectors
	const [newCollectorArtworkUri, setNewCollectorArtworkUri] = useState("");

	// Selection updates
	const [selectedArtworkIndex, setSelectedArtworkIndex] = useState(0);
	const [selectedThumbnailIndex, setSelectedThumbnailIndex] = useState(0);

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
		abi: multiplexAbi,
		address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
		functionName: "tokenData",
		args: [creator, BigInt(tokenId || 0)],
		query: { enabled: !!creator && !!tokenId },
	});

	// Normalize ABI-inferred tuple to an object without manual interfaces
	const token = useMemo(() => {
		if (!tokenData) return undefined;
		const [
			metadata,
			onChainThumbnail,
			displayMode,
			immutableProperties,
			offchain,
			selection,
			metadataLocked,
			thumbnailLocked,
		] = tokenData;
		return {
			metadata,
			onChainThumbnail,
			displayMode,
			immutableProperties,
			offchain,
			selection,
			metadataLocked,
			thumbnailLocked,
		} as const;
	}, [tokenData]);

	// Read artist artwork URIs
	const { data: artistArtworkUris, refetch: refetchArtworkUris } =
		useReadContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "getArtistArtworkUris",
			args: [creator, BigInt(tokenId || 0)],
			query: { enabled: !!creator && !!tokenId },
		});

	// Read collector artwork URIs
	const { data: collectorArtworkUris, refetch: refetchCollectorUris } =
		useReadContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "getCollectorArtworkUris",
			args: [creator, BigInt(tokenId || 0)],
			query: { enabled: !!creator && !!tokenId },
		});

	// Read artist thumbnail URIs
	const { data: artistThumbnailUris, refetch: refetchThumbnailUris } =
		useReadContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "getArtistThumbnailUris",
			args: [creator, BigInt(tokenId || 0)],
			query: { enabled: !!creator && !!tokenId },
		});

	// Test contract connection with a simple view function
	const { data: htmlTemplate, error: contractError } = useReadContract({
		abi: multiplexAbi,
		address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
		functionName: "getHtmlTemplate",
		args: [],
		query: { enabled: true },
	});



	// Initialize data from contract when tokenData loads
	useEffect(() => {
		if (token) {
			setDisplayMode(Number(token.displayMode));
			setSelectedArtworkIndex(Number(token.selection.selectedArtistArtworkIndex));
			setSelectedThumbnailIndex(Number(token.selection.selectedArtistThumbnailIndex));
		}
	}, [token]);

	// Derived permissions from contract data
	const permissions = useMemo(() => {
		const props = token?.immutableProperties;
		return {
			allowToggleDisplay: props?.allowCollectorToggleDisplayMode ?? false,
			allowSelectArtwork: props?.allowCollectorSelectArtistArtwork ?? false,
			allowSelectThumbnail: props?.allowCollectorSelectArtistThumbnail ?? false,
			allowAddArtwork: props?.allowCollectorAddArtwork ?? false,
			isHtmlMode: displayMode === 1,
		};
	}, [token?.immutableProperties, displayMode]);

	const { allowToggleDisplay, allowSelectArtwork, allowSelectThumbnail, allowAddArtwork, isHtmlMode } = permissions;

	// Debug logging
	useEffect(() => {
		console.log(
			"CollectorZone Debug - Contract Address:",
			import.meta.env.VITE_MULTIPLEX_ADDRESS
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
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "updateToken",
			args: [
				creator,
				BigInt(tokenId),
				{
					metadata: "",
					updateMetadata: false,
					thumbnailChunks: [],
					thumbnailOptions: {
						mimeType: "",
						chunks: [],
						length: 0n,
						zipped: false,
						deflated: false,
					},
					updateThumbnail: false,
					displayMode,
					updateDisplayMode: true,
					selectedArtistArtworkIndex: 0n,
					updateSelectedArtistArtwork: false,
					selectedArtistThumbnailIndex: 0n,
					updateSelectedArtistThumbnail: false,
				},
			],
		});
	};

	const updateSelection = (type: "artwork" | "thumbnail") => {
		const params = {
			metadata: "",
			updateMetadata: false,
			thumbnailChunks: [],
			thumbnailOptions: {
				mimeType: "",
				chunks: [],
				length: 0n,
				zipped: false,
				deflated: false,
			},
			updateThumbnail: false,
			displayMode: 0,
			updateDisplayMode: false,
			selectedArtistArtworkIndex:
				type === "artwork" ? BigInt(selectedArtworkIndex) : 0n,
			updateSelectedArtistArtwork: type === "artwork",
			selectedArtistThumbnailIndex:
				type === "thumbnail" ? BigInt(selectedThumbnailIndex) : 0n,
			updateSelectedArtistThumbnail: type === "thumbnail",
		};

		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "updateToken",
			args: [creator, BigInt(tokenId), params],
		});
	};

	const addCollectorArtworkUri = () => {
		if (!newCollectorArtworkUri.trim()) return;
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "addCollectorArtworkUris",
			args: [creator, BigInt(tokenId), [newCollectorArtworkUri.trim()]],
		});
		setNewCollectorArtworkUri("");
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
				<p className="text-zinc-400">Please select a collection first.</p>
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
				<h2 className="text-2xl font-display font-bold text-zinc-100 mb-2">
					Token Updated!
				</h2>
				<p className="text-zinc-400 mb-8">
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
		<div className="min-h-screen">
			<div className="flex justify-between items-center p-8 border-b border-zinc-800">
				<Link to="/" className="text-2xl font-black text-zinc-100">
					multiplex
				</Link>
				<ConnectButton />
			</div>

			<div className="max-w-4xl mx-auto px-8 py-8 space-y-8 animate-fade-in">
				<div>
					<h2 className="text-2xl font-display font-bold text-zinc-100">
						Collector Zone
					</h2>
					<p className="text-zinc-400 mt-1">
						Update tokens you own based on artist permissions
					</p>
				</div>

				{/* Token Selection */}
				<div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						1. Select Your Token
					</h3>
					<div className="space-y-4">
						<div>
							<label className="label">Collection Address</label>
							<p className="text-sm text-zinc-400 font-mono">{creator}</p>
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
							<div className="mt-4 p-4 bg-zinc-800 rounded-lg">
								<p className="text-sm text-zinc-300 mb-3">Your Permissions:</p>
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
									<span
										className={`${
											allowSelectThumbnail ? "text-green-400" : "text-red-400"
										}`}
									>
										Select Thumbnail:{" "}
										{allowSelectThumbnail ? "Allowed" : "Disabled"}
									</span>
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
							<div className="mt-4 p-3 bg-zinc-900 rounded text-xs">
								<div className="flex justify-between items-center">
									<span className="text-zinc-400">Contract Status:</span>
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
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							2. Display Mode
						</h3>
						<div className="space-y-4">
							<div>
								<label className="label">Current Display Mode</label>
								<select
									className="input-field"
									value={displayMode}
									onChange={(e) =>
										setDisplayMode(Number(e.target.value))
									}
								>
									<option value={0}>Image</option>
									<option value={1}>Interactive HTML</option>
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
								{isPending || isConfirming ? "Updating..." : "Update Display Mode"}
							</button>
						</div>
					</div>
				) : null}

				{/* Artwork Selection */}
				{tokenData &&
				allowSelectArtwork &&
				artistArtworkUris &&
				artistArtworkUris.length > 0 ? (
					<div className="card">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							3. Select Artwork
						</h3>
						<div className="space-y-4">
							<div className="space-y-2">
								<p className="text-sm text-zinc-400">
									Available artworks from artist:
								</p>
								{(artistArtworkUris).map((uri: string, index: number) => (
									<div
										key={index}
										className="flex gap-2 items-center p-2 bg-zinc-800 rounded"
									>
										<input
											type="radio"
											name="artwork"
											value={index + 1}
											checked={selectedArtworkIndex === index + 1}
											onChange={() => setSelectedArtworkIndex(index + 1)}
											className="mr-2"
										/>
										<span className="flex-1 text-sm font-mono text-zinc-300 break-all">
											{uri}
										</span>
									</div>
								))}
								<div className="flex gap-2 items-center p-2 bg-zinc-800 rounded">
									<input
										type="radio"
										name="artwork"
										value={0}
										checked={selectedArtworkIndex === 0}
										onChange={() => setSelectedArtworkIndex(0)}
										className="mr-2"
									/>
									<span className="flex-1 text-sm text-zinc-300">
										None selected
									</span>
								</div>
							</div>
							<button
								type="button"
								onClick={() => updateSelection("artwork")}
								className="btn-primary"
								disabled={isPending || isConfirming}
							>
								{isPending || isConfirming ? "Updating..." : "Update Artwork Selection"}
							</button>
						</div>
					</div>
				) : null}

				{/* Thumbnail Selection */}
				{tokenData &&
				allowSelectThumbnail &&
				artistThumbnailUris &&
				artistThumbnailUris.length > 0 ? (
					<div className="card">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							4. Select Thumbnail
						</h3>
						<div className="space-y-4">
							<div className="space-y-2">
								<p className="text-sm text-zinc-400">
									Available thumbnails from artist:
								</p>
								{(artistThumbnailUris).map((uri: string, index: number) => (
									<div
										key={index}
										className="flex gap-2 items-center p-2 bg-zinc-800 rounded"
									>
										<input
											type="radio"
											name="thumbnail"
											value={index + 1}
											checked={selectedThumbnailIndex === index + 1}
											onChange={() => setSelectedThumbnailIndex(index + 1)}
											className="mr-2"
										/>
										<span className="flex-1 text-sm font-mono text-zinc-300 break-all">
											{uri}
										</span>
									</div>
								))}
								<div className="flex gap-2 items-center p-2 bg-zinc-800 rounded">
									<input
										type="radio"
										name="thumbnail"
										value={0}
										checked={selectedThumbnailIndex === 0}
										onChange={() => setSelectedThumbnailIndex(0)}
										className="mr-2"
									/>
									<span className="flex-1 text-sm text-zinc-300">
										Use on-chain thumbnail
									</span>
								</div>
							</div>
							<button
								type="button"
								onClick={() => updateSelection("thumbnail")}
								className="btn-primary"
								disabled={isPending || isConfirming}
							>
								{isPending || isConfirming ? "Updating..." : "Update Thumbnail Selection"}
							</button>
						</div>
					</div>
				) : null}

				{/* Add Collector Artwork */}
				{tokenData && allowAddArtwork && isHtmlMode ? (
					<div className="card">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							5. Add Your Artwork
						</h3>
						<div className="space-y-4">
							<div className="flex gap-2">
								<input
									className="input-field flex-1"
									placeholder="ipfs://... or https://..."
									value={newCollectorArtworkUri}
									onChange={(e) => setNewCollectorArtworkUri(e.target.value)}
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
									<p className="text-sm text-zinc-400">Your artwork URIs:</p>
									{(collectorArtworkUris).map((uri: string, index: number) => (
										<div
											key={index}
											className="flex gap-2 items-center p-2 bg-zinc-800 rounded"
										>
											<span className="flex-1 text-sm font-mono text-zinc-300 break-all">
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
				!allowSelectThumbnail &&
				!allowAddArtwork ? (
					<div className="card bg-zinc-900 border-zinc-700">
						<div className="flex items-center gap-3">
							<svg
								className="w-6 h-6 text-zinc-400"
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
								<p className="text-zinc-300 font-medium">
									No Collector Permissions
								</p>
								<p className="text-zinc-400 text-sm">
									This token doesn't allow any collector updates. All settings
									are controlled by the artist.
								</p>
							</div>
						</div>
					</div>
				) : null}

				{/* Status Messages */}
				{hash && !isSuccess && (
					<div className="text-center text-sm text-zinc-400">
						Transaction submitted. Waiting for confirmation...
					</div>
				)}

				{/* Loading and Error Messages */}
				{tokenDataLoading && tokenId && (
					<div className="text-center text-sm text-zinc-400">
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
							<h3 className="text-lg text-yellow-300 mb-2">Token Not Found</h3>
							<p className="text-yellow-200 text-sm">
								Token #{tokenId} was not found in this collection or you don't
								own it.
							</p>
						</div>
					</div>
				)}
			</div>
		</div>
	);
}