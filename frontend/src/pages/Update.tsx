import { useMemo, useState, useCallback, useEffect } from "react";
import {
	useWriteContract,
	useWaitForTransactionReceipt,
	useReadContract,
} from "wagmi";
import { useSearchParams, useNavigate, Link } from "react-router-dom";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import type { Address } from "viem";
import { multiplexAbi } from "../abis/multiplex-abi";
import fastlz from "../lib/fastlz";
import {
	isThumbnailSupported,
	getThumbnailAcceptAttribute,
	getUnsupportedThumbnailMessage,
} from "../utils/fileValidation";
import FilePreview from "../components/FilePreview";
import type { Attribute } from "../types/metadata";

export default function Update() {
	const [sp] = useSearchParams();
	const navigate = useNavigate();
	const creator = (sp.get("creator") || "") as Address;

  // Token to update
	const [tokenId, setTokenId] = useState("");

  // Metadata
	const [name, setName] = useState("");
	const [description, setDescription] = useState("");
	const [externalUrl, setExternalUrl] = useState("");
	const [attributes, setAttributes] = useState<Attribute[]>([]);

	// Thumbnail (on-chain)
	const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
	const [thumbnailPreview, setThumbnailPreview] = useState<string>("");
	const [thumbMime, setThumbMime] = useState("");
	const [thumbLength, setThumbLength] = useState<number>(0);
	const [thumbChunks, setThumbChunks] = useState<string[]>([]);

	// Display mode
	const [displayMode, setDisplayMode] = useState(1);

	// URI management
	const [newArtworkUri, setNewArtworkUri] = useState("");
	const [newThumbnailUri, setNewThumbnailUri] = useState("");

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

	// Test contract connection with a simple view function
	const { data: htmlTemplate, error: contractError } = useReadContract({
		abi: multiplexAbi,
		address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
		functionName: "getHtmlTemplate",
		args: [],
		query: { enabled: true },
	});

	// Debug logging
	useEffect(() => {
		console.log(
			"Debug - Contract Address:",
			import.meta.env.VITE_MULTIPLEX_ADDRESS
		);
		console.log("Debug - Creator:", creator);
		console.log("Debug - Token ID:", tokenId);
		console.log("Debug - Token Data:", tokenData);
		console.log("Debug - Token Data Error:", tokenDataError);
		console.log("Debug - Token Data Loading:", tokenDataLoading);
		console.log(
			"Debug - Contract Connection Test:",
			htmlTemplate ? "Connected" : "Failed"
		);
		console.log("Debug - Contract Error:", contractError);
	}, [
		creator,
		tokenId,
		tokenData,
		tokenDataError,
		tokenDataLoading,
		htmlTemplate,
		contractError,
	]);

	// Read artist artwork URIs
	const { data: artistArtworkUris, refetch: refetchArtworkUris } =
		useReadContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "getArtistArtworkUris",
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

	// Initialize data from contract when tokenData loads
	useEffect(() => {
		if (token) {
			setDisplayMode(Number(token.displayMode));
			setSelectedArtworkIndex(Number(token.selection.selectedArtistArtworkIndex));
			setSelectedThumbnailIndex(Number(token.selection.selectedArtistThumbnailIndex));
		}
	}, [token]);

	// Derived state from contract data
	const isOnChainThumbnail = token
		? !token.immutableProperties.useOffchainThumbnail
		: true;
	const isMetadataLocked = token ? token.metadataLocked : false;
	const isThumbnailLocked = token ? token.thumbnailLocked : false;

  const prepareThumbnail = useCallback(async (file: File) => {
		setThumbnailFile(file);
		setThumbMime(file.type);
    
    // Create preview
		const reader = new FileReader();
		reader.onload = (e) => setThumbnailPreview(e.target?.result as string);
		reader.readAsDataURL(file);
    
    // Compress and chunk
		const buffer = await file.arrayBuffer();
		const compressed = fastlz.compress(new Uint8Array(buffer));
		setThumbLength(buffer.byteLength);

		const CHUNK_SIZE = 23 * 1024; // 23KB per chunk
		const chunks: string[] = [];
		for (let i = 0; i < compressed.length; i += CHUNK_SIZE) {
			const chunk = compressed.slice(i, i + CHUNK_SIZE);
			chunks.push(
				`0x${Array.from(chunk)
					.map((b) => (b as number).toString(16).padStart(2, "0"))
					.join("")}`
			);
		}
		setThumbChunks(chunks);
	}, []);

  const handleAddAttribute = () => {
		setAttributes([...attributes, { trait_type: "", value: "" }]);
	};

	const handleAttributeChange = (
		index: number,
		field: keyof Attribute,
		value: string | number
	) => {
		const newAttributes = [...attributes];
		// @ts-expect-error - dynamic field assignment
		newAttributes[index][field] = value;
		setAttributes(newAttributes);
	};

  const handleRemoveAttribute = (index: number) => {
		setAttributes(attributes.filter((_, i) => i !== index));
	};

  const metadataJson = useMemo(() => {
		const fields: string[] = [];
		if (name) fields.push(`"name":${JSON.stringify(name)}`);
		if (description) fields.push(`"description":${JSON.stringify(description)}`);
		if (externalUrl) fields.push(`"external_url":${JSON.stringify(externalUrl)}`);
    if (attributes.length > 0) {
			const validAttrs = attributes
				.filter((a) => a.trait_type && a.value !== "")
				.map((attr) => {
					const parts = [
						`"trait_type":${JSON.stringify(attr.trait_type)}`,
						`"value":${JSON.stringify(attr.value)}`,
					];
					if (attr.display_type) {
						parts.push(`"display_type":${JSON.stringify(attr.display_type)}`);
					}
					return `{${parts.join(",")}}`;
				});
			if (validAttrs.length > 0) {
				fields.push(`"attributes":[${validAttrs.join(",")}]`);
			}
		}
		return fields.join(",");
	}, [name, description, externalUrl, attributes]);

	// Contract interaction functions
	const lockMetadata = () => {
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "lockMetadata",
			args: [creator, BigInt(tokenId)],
		});
	};

	const lockThumbnail = () => {
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "lockThumbnail",
			args: [creator, BigInt(tokenId)],
		});
	};

	const addArtworkUri = () => {
		if (!newArtworkUri.trim()) return;
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "addArtistArtworkUris",
			args: [creator, BigInt(tokenId), [newArtworkUri.trim()]],
		});
		setNewArtworkUri("");
	};

	const removeArtworkUri = (index: number) => {
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "removeArtistArtworkUri",
			args: [creator, BigInt(tokenId), BigInt(index)],
		});
	};

	const addThumbnailUri = () => {
		if (!newThumbnailUri.trim()) return;
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "addArtistThumbnailUris",
			args: [creator, BigInt(tokenId), [newThumbnailUri.trim()]],
		});
		setNewThumbnailUri("");
	};

	const removeThumbnailUri = (index: number) => {
		writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "removeArtistThumbnailUri",
			args: [creator, BigInt(tokenId), BigInt(index)],
		});
	};

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

	const updateParams = useMemo(
		() => ({
    metadata: metadataJson,
    updateMetadata: metadataJson.length > 0,
			thumbnailChunks: thumbChunks as readonly `0x${string}`[],
    thumbnailOptions: {
				mimeType: thumbMime || "",
				chunks: [] as readonly Address[], // This will be populated by the contract
      length: BigInt(thumbLength || 0),
				zipped: true,
				deflated: false,
    },
    updateThumbnail: thumbChunks.length > 0,
    displayMode: 0, // Default, not updating
    updateDisplayMode: false,
    selectedArtistArtworkIndex: BigInt(0),
    updateSelectedArtistArtwork: false,
    selectedArtistThumbnailIndex: BigInt(0),
    updateSelectedArtistThumbnail: false,
		}),
		[metadataJson, thumbMime, thumbChunks, thumbLength]
	);

  const onSubmit = (e: React.FormEvent) => {
		e.preventDefault();
    
    writeContract({
			abi: multiplexAbi,
			address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
			functionName: "updateToken",
      args: [creator, BigInt(tokenId), updateParams],
		});
	};

	// Effect to refetch data after successful transactions
	useEffect(() => {
		if (isSuccess) {
			refetchTokenData();
			refetchArtworkUris();
			refetchThumbnailUris();
		}
	}, [isSuccess, refetchTokenData, refetchArtworkUris, refetchThumbnailUris]);

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
					Artwork Updated!
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
						Update Artwork
					</h2>
					<p className="text-zinc-400 mt-1">
						Manage and update existing token properties
					</p>
      </div>

      {/* Token Selection */}
      <div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						1. Select Token
					</h3>
        <div>
          <label className="label">Token ID *</label>
          <input
            className="input-field"
            placeholder="Enter token ID number"
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            required
          />
          <p className="help-text">The ID of the token you want to update</p>
        </div>

					{
						(tokenData && (
							<div className="mt-4 p-4 bg-zinc-800 rounded-lg">
								<p className="text-sm text-zinc-300">Token Status:</p>
								<div className="flex gap-4 mt-2">
									<span
										className={`text-sm ${
											isMetadataLocked ? "text-red-400" : "text-green-400"
										}`}
									>
										Metadata: {isMetadataLocked ? "Locked" : "Unlocked"}
									</span>
									<span
										className={`text-sm ${
											isThumbnailLocked ? "text-red-400" : "text-green-400"
										}`}
									>
										Thumbnail: {isThumbnailLocked ? "Locked" : "Unlocked"}
									</span>
									<span className="text-sm text-zinc-400">
										Thumbnail Type:{" "}
										{isOnChainThumbnail ? "On-chain" : "Off-chain"}
									</span>
								</div>
							</div>
						)) as React.ReactNode
					}

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
						{contractError && (
							<p className="text-red-400 mt-2 text-xs">
								Error: {contractError.message}
							</p>
						)}
					</div>
      </div>

				{/* All Update Sections - Only show when token data is loaded */}
				{
					(tokenData && (
						<div className="space-y-8">
							{/* Metadata Updates */}
							<form onSubmit={onSubmit}>
      <div className="card">
									<div className="flex justify-between items-center mb-4">
										<h3 className="text-lg font-semibold text-zinc-100">
											2. Update Metadata
										</h3>
										{!isMetadataLocked && (
											<button
												type="button"
												onClick={lockMetadata}
												className="btn-ghost text-red-400 hover:text-red-300"
											>
												🔒 Lock Metadata
											</button>
										)}
									</div>

									{isMetadataLocked ? (
										<p className="text-red-400">
											Metadata is locked and cannot be updated.
										</p>
									) : (
										<>
											<p className="text-zinc-400 mb-4">
												Leave fields empty to keep existing values
											</p>
        
        <div className="space-y-4">
          <div>
            <label className="label">New Title</label>
            <input
              className="input-field"
              placeholder="Updated artwork title"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
          <div>
            <label className="label">New Description</label>
            <textarea
              rows={4}
              className="textarea-field"
              placeholder="Updated description..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>
          <div>
            <label className="label">New External Link</label>
            <input
              className="input-field"
														placeholder="https://updatedlink.com"
              value={externalUrl}
              onChange={(e) => setExternalUrl(e.target.value)}
            />
          </div>
        </div>

        <div className="mt-6">
												<label className="label">Properties</label>
												<p className="help-text mb-3">
													Update or add new attributes
												</p>
          {attributes.map((attr, index) => (
            <div key={index} className="flex gap-2 mb-2">
              <input
                className="input-field flex-1"
                placeholder="Property"
                value={attr.trait_type}
															onChange={(e) =>
																handleAttributeChange(
																	index,
																	"trait_type",
																	e.target.value
																)
															}
              />
              <input
                className="input-field flex-1"
                placeholder="Value"
                value={attr.value}
															onChange={(e) =>
																handleAttributeChange(
																	index,
																	"value",
																	e.target.value
																)
															}
														/>
														<button
															type="button"
															onClick={() => handleRemoveAttribute(index)}
															className="btn-ghost"
														>
															<svg
																className="w-5 h-5"
																fill="none"
																stroke="currentColor"
																viewBox="0 0 24 24"
															>
																<path
																	strokeLinecap="round"
																	strokeLinejoin="round"
																	strokeWidth={2}
																	d="M6 18L18 6M6 6l12 12"
																/>
                </svg>
              </button>
            </div>
          ))}
												<button
													type="button"
													onClick={handleAddAttribute}
													className="btn-secondary text-sm"
												>
            + Add Property
          </button>
											</div>

											<div className="flex justify-end mt-6">
												<button
													type="submit"
													className="btn-primary"
													disabled={!metadataJson || isPending || isConfirming}
												>
													{isPending || isConfirming
														? "Updating..."
														: "Update Metadata"}
												</button>
											</div>
										</>
									)}
								</div>
							</form>

							{/* Display Mode */}
							<div className="card">
								<h3 className="text-lg font-semibold text-zinc-100 mb-4">
									3. Display Mode
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
											<option value={1}>Interactive HTML</option>
										</select>
									</div>
									<button
										type="button"
										onClick={updateDisplayMode}
										className="btn-secondary"
									>
										Update Display Mode
									</button>
								</div>
							</div>

							{/* Artwork URI Management */}
							<div className="card">
								<h3 className="text-lg font-semibold text-zinc-100 mb-4">
									4. Artwork URIs
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
											onClick={addArtworkUri}
											className="btn-primary"
										>
											Add
										</button>
									</div>

									{
										(artistArtworkUris && artistArtworkUris.length > 0 && (
											<div className="space-y-2">
												<p className="text-sm text-zinc-400">
													Current artwork URIs:
												</p>
												{artistArtworkUris.map((uri: string, index: number) => (
													<div
														key={index}
														className="flex gap-2 items-center p-2 bg-zinc-800 rounded"
													>
														<span className="flex-1 text-sm font-mono text-zinc-300 break-all">
															{uri}
														</span>
														<button
															type="button"
															onClick={() => removeArtworkUri(index)}
															className="btn-ghost text-red-400 hover:text-red-300 p-1"
														>
															✕
														</button>
													</div>
												))}
											</div>
										)) as React.ReactNode
									}

									{
										(artistArtworkUris && artistArtworkUris.length > 0 && (
											<div>
												<label className="label">
													Selected Artwork (1-based, 0 = none)
												</label>
												<input
													type="number"
													className="input-field"
													min="0"
													max={artistArtworkUris.length}
													value={selectedArtworkIndex}
													onChange={(e) =>
														setSelectedArtworkIndex(
															parseInt(e.target.value) || 0
														)
													}
												/>
												<button
													type="button"
													onClick={() => updateSelection("artwork")}
													className="btn-secondary mt-2"
												>
													Update Selection
												</button>
											</div>
										)) as React.ReactNode
									}
        </div>
      </div>

							{/* Thumbnail Management */}
      <div className="card">
								<div className="flex justify-between items-center mb-4">
									<h3 className="text-lg font-semibold text-zinc-100">
										5. Thumbnail Management
									</h3>
									{!isThumbnailLocked && (
										<button
											type="button"
											onClick={lockThumbnail}
											className="btn-ghost text-red-400 hover:text-red-300"
										>
											🔒 Lock Thumbnail
										</button>
									)}
								</div>

								{isThumbnailLocked ? (
									<p className="text-red-400">
										Thumbnail is locked and cannot be updated.
									</p>
								) : isOnChainThumbnail ? (
									<div>
										<p className="text-zinc-400 mb-4">
											Upload a new on-chain thumbnail file
										</p>
										<div
											className={`upload-zone ${thumbnailFile ? "active" : ""}`}
											onDragOver={(e) => {
												e.preventDefault();
												e.currentTarget.classList.add("active");
											}}
											onDragLeave={(e) => {
												e.currentTarget.classList.remove("active");
											}}
          onDrop={(e) => {
												e.preventDefault();
												e.currentTarget.classList.remove("active");
												const file = e.dataTransfer.files?.[0];
												if (file && isThumbnailSupported(file)) {
													prepareThumbnail(file);
												} else if (file) {
													alert(getUnsupportedThumbnailMessage(file));
												}
          }}
          onClick={() => {
												const input = document.createElement("input");
												input.type = "file";
												input.accept = getThumbnailAcceptAttribute();
            input.onchange = () => {
													const file = input.files?.[0];
													if (file && isThumbnailSupported(file)) {
														prepareThumbnail(file);
													} else if (file) {
														alert(getUnsupportedThumbnailMessage(file));
													}
												};
												input.click();
          }}
        >
          {thumbnailPreview ? (
            <div className="space-y-2">
													<FilePreview
														file={thumbnailFile}
														previewUrl={thumbnailPreview}
														maxHeight="max-h-32"
													/>
													<p className="text-sm text-zinc-400 text-center">
														{thumbChunks.length} chunks • {thumbLength} bytes
														original
              </p>
            </div>
          ) : (
            <>
													<svg
														className="w-8 h-8 text-gray-400 mx-auto mb-2"
														fill="none"
														stroke="currentColor"
														viewBox="0 0 24 24"
													>
														<path
															strokeLinecap="round"
															strokeLinejoin="round"
															strokeWidth={2}
															d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
														/>
              </svg>
													<p className="text-zinc-400 text-sm">
														Drop a new thumbnail or click to browse
													</p>
            </>
          )}
        </div>
      </div>
								) : (
									<div className="space-y-4">
										<p className="text-zinc-400">
											Manage off-chain thumbnail URIs
										</p>
										<div className="flex gap-2">
											<input
												className="input-field flex-1"
												placeholder="ipfs://... or https://..."
												value={newThumbnailUri}
												onChange={(e) => setNewThumbnailUri(e.target.value)}
											/>
											<button
												type="button"
												onClick={addThumbnailUri}
												className="btn-primary"
											>
												Add
											</button>
      </div>

										{
											(artistThumbnailUris &&
												artistThumbnailUris.length > 0 && (
													<div className="space-y-2">
														<p className="text-sm text-zinc-400">
															Current thumbnail URIs:
														</p>
														{(artistThumbnailUris).map(
															(uri: string, index: number) => (
																<div
																	key={index}
																	className="flex gap-2 items-center p-2 bg-zinc-800 rounded"
																>
																	<span className="flex-1 text-sm font-mono text-zinc-300 break-all">
																		{uri}
																	</span>
																	<button
																		type="button"
																		onClick={() => removeThumbnailUri(index)}
																		className="btn-ghost text-red-400 hover:text-red-300 p-1"
																	>
																		✕
        </button>
																</div>
															)
														)}
													</div>
												)) as React.ReactNode
										}

										{
											(artistThumbnailUris &&
												artistThumbnailUris.length > 0 && (
													<div>
														<label className="label">
															Selected Thumbnail (1-based, 0 = on-chain)
														</label>
														<input
															type="number"
															className="input-field"
															min="0"
															max={artistThumbnailUris.length}
															value={selectedThumbnailIndex}
															onChange={(e) =>
																setSelectedThumbnailIndex(
																	parseInt(e.target.value) || 0
																)
															}
														/>
        <button
															type="button"
															onClick={() => updateSelection("thumbnail")}
															className="btn-secondary mt-2"
														>
															Update Selection
        </button>
      </div>
												)) as React.ReactNode
										}
									</div>
								)}
							</div>
						</div>
					)) as React.ReactNode
				}

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
									<li>• Contract not deployed or wrong address</li>
									<li>• Network connection issue</li>
									<li>• Wrong collection address</li>
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
								Token #{tokenId} was not found in this collection. Make sure the
								token exists and you've entered the correct ID.
							</p>
						</div>
					</div>
				)}

				{!tokenId && (
					<div className="space-y-8">
						{/* Preview of what will be available */}
						<div className="card bg-zinc-900 border-zinc-700 opacity-60">
							<h3 className="text-lg font-semibold text-zinc-100 mb-4">
								2. Update Metadata
							</h3>
							<p className="text-zinc-400">
								Update name, description, and properties (available after
								entering token ID)
							</p>
						</div>

						<div className="card bg-zinc-900 border-zinc-700 opacity-60">
							<h3 className="text-lg font-semibold text-zinc-100 mb-4">
								3. Display Mode
							</h3>
							<p className="text-zinc-400">
								Switch between Image and Interactive HTML modes
							</p>
						</div>

						<div className="card bg-zinc-900 border-zinc-700 opacity-60">
							<h3 className="text-lg font-semibold text-zinc-100 mb-4">
								4. Artwork URIs
							</h3>
							<p className="text-zinc-400">
								Manage artist artwork URIs and selections
							</p>
						</div>

						<div className="card bg-zinc-900 border-zinc-700 opacity-60">
							<h3 className="text-lg font-semibold text-zinc-100 mb-4">
								5. Thumbnail Management
							</h3>
							<p className="text-zinc-400">
								Update on-chain thumbnails or manage off-chain thumbnail URIs
							</p>
						</div>

						<div className="card bg-blue-500 bg-opacity-10 border-blue-500 border-opacity-30">
							<div className="text-center py-6">
								<svg
									className="w-10 h-10 text-blue-400 mx-auto mb-3"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										strokeLinecap="round"
										strokeLinejoin="round"
										strokeWidth={2}
										d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
									/>
								</svg>
								<h3 className="text-lg text-blue-300 mb-2">
									Enter Token ID to Enable Updates
								</h3>
								<p className="text-blue-200 text-sm">
									All sections above will become interactive once you enter a
									valid token ID.
								</p>
							</div>
						</div>
					</div>
				)}
			</div>
    </div>
	);
}
