import { ConnectButton } from "@rainbow-me/rainbowkit";

interface ConnectButtonHeaderProps {
	isDarkMode: boolean;
}

export default function ConnectButtonHeader({ isDarkMode }: ConnectButtonHeaderProps) {
	return (
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
										className={`px-3 py-1 text-xs border rounded transition-colors ${
											isDarkMode
												? "border-zinc-600 text-zinc-400 hover:text-zinc-100 hover:border-zinc-400"
												: "border-zinc-300 text-zinc-600 hover:text-zinc-900 hover:border-zinc-600"
										}`}
									>
										Connect
									</button>
								);
							}

							if (chain.unsupported) {
								return (
									<button
										onClick={openChainModal}
										type="button"
										className={`px-3 py-1 text-xs border rounded transition-colors border-red-600 text-red-400 hover:text-red-300 hover:border-red-500`}
									>
										Wrong network
									</button>
								);
							}

							return (
								<div className="flex gap-2">
									<button
										onClick={openChainModal}
										className={`px-3 py-1 text-xs border rounded transition-colors ${
											isDarkMode
												? "border-zinc-600 text-zinc-400 hover:text-zinc-100 hover:border-zinc-400"
												: "border-zinc-300 text-zinc-600 hover:text-zinc-900 hover:border-zinc-600"
										}`}
										type="button"
									>
										{chain.name}
									</button>

									<button
										onClick={openAccountModal}
										type="button"
										className={`px-3 py-1 text-xs border rounded transition-colors ${
											isDarkMode
												? "border-zinc-600 text-zinc-400 hover:text-zinc-100 hover:border-zinc-400"
												: "border-zinc-300 text-zinc-600 hover:text-zinc-900 hover:border-zinc-600"
										}`}
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
	);
}
