import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function ConnectButtonPrimary() {
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
										className="btn-primary text-sm"
									>
										Connect Wallet
									</button>
								);
							}

							if (chain.unsupported) {
								return (
									<button
										onClick={openChainModal}
										type="button"
										className="px-6 py-3 bg-red-500 text-white font-bold hover:bg-red-600 transition-all"
									>
										Wrong Network
									</button>
								);
							}

							return (
								<div className="flex gap-2">
									<button
										onClick={openChainModal}
										className="btn-secondary text-sm"
										type="button"
									>
										{chain.name}
									</button>

									<button
										onClick={openAccountModal}
										type="button"
										className="btn-primary text-sm"
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
