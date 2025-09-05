import {
	useWriteContract,
	useWaitForTransactionReceipt,
	useReadContract,
	useSimulateContract,
} from "wagmi";
import type { Address } from "viem";
import { wayfinderAbi } from "../abis/wayfinder-abi";
import { useTheme } from "../hooks/useTheme";

interface RegisterWayfinderProps {
	creator: Address;
}

export default function RegisterWayfinder({ creator }: RegisterWayfinderProps) {
	const { isDarkMode } = useTheme();
	const wayfinderAddress = import.meta.env.VITE_WAYFINDER_ADDRESS as Address;
	const wayfinderExtensionAddress = import.meta.env
		.VITE_WAYFINDER_EXTENSION_ADDRESS as Address;

	const { data: hash, isPending, writeContract } = useWriteContract();
	const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
		hash,
	});

	// Check if contract is already registered with Wayfinder
	const { data: isRegistered } = useReadContract({
		abi: wayfinderAbi,
		address: wayfinderAddress,
		functionName: "isContractOperator",
		args: [creator, wayfinderExtensionAddress],
		query: { enabled: !!creator },
	});

	// Simulate the registration to catch errors
	const { error: simulateError } = useSimulateContract({
		abi: wayfinderAbi,
		address: wayfinderAddress,
		functionName: "registerContract",
		args: [creator, wayfinderExtensionAddress],
		query: { enabled: !!creator && !isRegistered },
	});

	const handleRegister = () => {
		writeContract({
			abi: wayfinderAbi,
			address: wayfinderAddress,
			functionName: "registerContract",
			args: [creator, wayfinderExtensionAddress],
		});
	};

	// Show success message for recent transaction
	if (isSuccess) {
		return (
			<div className="p-4 bg-success bg-opacity-10 border border-success border-opacity-20">
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
						Contract registered with Wayfinder successfully!
					</p>
				</div>
			</div>
		);
	}

	// Show already registered status
	if (isRegistered) {
		return (
			<div className="p-4 bg-success bg-opacity-10 border border-success border-opacity-20">
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
						Contract is already registered with Wayfinder!
					</p>
				</div>
			</div>
		);
	}

	return (
		<div
			className={`p-4 ${
				isDarkMode
					? "bg-zinc-800 border-zinc-700"
					: "bg-zinc-100 border-zinc-300"
			} border`}
		>
			<div className="flex items-start justify-between">
				<div>
					<h4
						className={`font-medium ${
							isDarkMode ? "text-zinc-100" : "text-zinc-900"
						}`}
					>
						Register with Wayfinder
					</h4>
					<p
						className={`text-sm ${
							isDarkMode ? "text-zinc-400" : "text-zinc-600"
						} mt-1`}
					>
						Required to enable Wayfinder features for this collection
					</p>
				</div>
			</div>

			<button
				onClick={handleRegister}
				className="btn-primary w-full mt-4"
				disabled={
					isPending ||
					isConfirming ||
					!creator ||
					isRegistered ||
					!!simulateError
				}
			>
				{isPending || isConfirming ? (
					<>
						<svg
							className="animate-spin -ml-1 mr-2 h-4 w-4 inline"
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
				) : isRegistered ? (
					"Already Registered"
				) : (
					"Register Contract"
				)}
			</button>

			{simulateError && (
				<div className="mt-2 p-3 bg-orange-500 bg-opacity-10 border border-orange-500 border-opacity-30 rounded">
					<p className="text-sm text-orange-300 font-medium">
						Transaction will fail:
					</p>
					<p className="text-xs text-orange-200 mt-1">
						{simulateError.message}
					</p>
				</div>
			)}

			{hash && !isSuccess && (
				<p className="text-sm text-zinc-400 mt-2">
					Transaction submitted. Waiting for confirmation...
				</p>
			)}
		</div>
	);
}
