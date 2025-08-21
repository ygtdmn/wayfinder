import { useWriteContract, useWaitForTransactionReceipt, useReadContract } from "wagmi";
import type { Address } from "viem";
import { ierc721CreatorCoreAbi } from "../abis/IERC721CreatorCore-abi";
import { ierc1155CreatorCoreAbi } from "../abis/IERC1155CreatorCore-abi";

interface RegisterExtensionProps {
	creator: Address;
	type: "ERC721" | "ERC1155";
}

export default function RegisterExtension({ creator, type }: RegisterExtensionProps) {
	const baseURI = "";
	const multiplexAddress = import.meta.env.VITE_MULTIPLEX_ADDRESS as Address;

	const coreAbi = type === "ERC721" ? ierc721CreatorCoreAbi : ierc1155CreatorCoreAbi;

	const { data: hash, isPending, writeContract } = useWriteContract();
	const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
		hash,
	});

	// Check if extension is already registered
	const { data: extensions } = useReadContract({
		abi: coreAbi,
		address: creator,
		functionName: "getExtensions",
		args: [],
		query: { enabled: !!creator },
	});

	const isExtensionRegistered = extensions && Array.isArray(extensions)
		? extensions.includes(multiplexAddress)
		: false;

	const handleRegister = () => {
		writeContract({
			abi: coreAbi,
			address: creator,
			functionName: "registerExtension",
			args: [multiplexAddress, baseURI],
		});
	};

	if (isSuccess || isExtensionRegistered) {
		return (
			<div className="p-4 bg-success bg-opacity-10  border border-success border-opacity-20">
				<div className="flex items-center">
					<svg
						className="w-5 h-5 text-success mr-2"
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
					<p className="text-sm text-success font-medium">
						{isSuccess 
							? "Multiplex extension registered successfully!" 
							: "Multiplex extension is already registered!"}
					</p>
				</div>
			</div>
		);
	}

	return (
		<div className="p-4 bg-zinc-800  border border-zinc-700">
			<div className="flex items-start justify-between">
				<div>
					<h4 className="font-medium text-zinc-100">
						Register Multiplex Extension
					</h4>
					<p className="text-sm text-zinc-400 mt-1">
						Required to use Multiplex features with this collection
					</p>
				</div>
			</div>

			<button
				onClick={handleRegister}
				className="btn-primary w-full mt-4"
				disabled={isPending || isConfirming || !creator || isExtensionRegistered}
			>
				{isPending || isConfirming ? (
					<>
						<svg
							className="animate-spin -ml-1 mr-2 h-4 w-4 text-black inline"
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
						{isPending ? "Registering..." : "Confirming..."}
					</>
				) : isExtensionRegistered ? (
					"Already Registered"
				) : (
					"Register Extension"
				)}
			</button>

			{hash && !isSuccess && (
				<p className="text-sm text-zinc-400 mt-2">
					Transaction submitted. Waiting for confirmation...
				</p>
			)}
		</div>
	);
}
