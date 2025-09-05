import { useState, useEffect } from "react";
import { useAccount, useSignMessage } from "wagmi";

const CLIENT_ID = import.meta.env.VITE_MANIFOLD_CLIENT_ID || "";
const APP_NAME = import.meta.env.VITE_MANIFOLD_APP_NAME || "";

// Cookie management helpers
const COOKIE_NAMES = {
	ACCESS_TOKEN: "manifold_access_token",
	SESSION_TOKEN: "manifold_session_token",
	EXPIRES_AT: "manifold_expires_at",
};

function setCookie(name: string, value: string, hoursToExpire: number = 1) {
	const expires = new Date();
	expires.setTime(expires.getTime() + hoursToExpire * 60 * 60 * 1000);
	const isSecure = location.protocol === 'https:';
	const secureFlag = isSecure ? '; Secure' : '';
	document.cookie = `${name}=${value}; expires=${expires.toUTCString()}; path=/; SameSite=Strict${secureFlag}`;
}

function getCookie(name: string): string | null {
	const nameEQ = name + "=";
	const ca = document.cookie.split(";");
	for (let i = 0; i < ca.length; i++) {
		let c = ca[i];
		while (c.charAt(0) === " ") c = c.substring(1, c.length);
		if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
	}
	return null;
}

function deleteCookie(name: string) {
	document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
}

function isAuthExpired(): boolean {
	const expiresAt = getCookie(COOKIE_NAMES.EXPIRES_AT);
	if (!expiresAt) return true;
	return Date.now() > parseInt(expiresAt);
}

function clearAuthCookies() {
	deleteCookie(COOKIE_NAMES.ACCESS_TOKEN);
	deleteCookie(COOKIE_NAMES.SESSION_TOKEN);
	deleteCookie(COOKIE_NAMES.EXPIRES_AT);
}

export function useManifoldAuth() {
	const { address, chainId } = useAccount();
	const { signMessageAsync } = useSignMessage();
	const [token, setToken] = useState("");
	const [session, setSession] = useState("");
	const [isAuthenticating, setIsAuthenticating] = useState(false);
	const [authenticatedAddress, setAuthenticatedAddress] = useState<string | null>(null);

	// Initialize from cookies on mount
	useEffect(() => {
		if (isAuthExpired()) {
			clearAuthCookies();
			setToken("");
			setSession("");
		} else {
			const accessToken = getCookie(COOKIE_NAMES.ACCESS_TOKEN);
			const sessionToken = getCookie(COOKIE_NAMES.SESSION_TOKEN);
			
			if (accessToken) setToken(accessToken);
			if (sessionToken) setSession(sessionToken);
		}
	}, []);

	// Set authenticated address when we have both tokens and address
	useEffect(() => {
		if (token && session && address) {
			setAuthenticatedAddress(address);
		}
	}, [token, session, address]);

	// Clear authentication state when wallet address changes
	useEffect(() => {
		// Clear tokens when address changes (wallet switch)
		clearAuthCookies();
		setToken("");
		setSession("");
		setAuthenticatedAddress(null);
	}, [address]);

	const authenticate = async () => {
		if (!address || !chainId || isAuthenticating) return;
		
		// Check if we already have valid tokens in cookies
		if (!isAuthExpired() && token && session) {
			return { token, session };
		}

		try {
			setIsAuthenticating(true);

			// Generate code verifier and challenge for PKCE
			const codeVerifier = generateCodeVerifier();
			const codeChallenge = await generateCodeChallenge(codeVerifier);

			// Step 1: Get OAuth code
			const authResponse = await fetch("https://oauth2.manifoldxyz.dev/auth", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
				},
				body: JSON.stringify({
					address,
					clientId: CLIENT_ID,
					grantType: "signature",
					codeChallenge,
				}),
			});

			const authData = await authResponse.json();
			const oauthCode = authData.oauth_code;

			if (!oauthCode) throw new Error("Failed to get OAuth code");

			// Step 2: Sign the message
			const message = `Please sign this to allow ${APP_NAME} access to view your NFTs.\n\nChallenge: ${oauthCode}`;
			const signature = await signMessageAsync({ message });

			// Step 3: Exchange for access token
			const tokenBody = {
				clientId: CLIENT_ID,
				appName: APP_NAME,
				codeVerifier,
				chainId,
				message,
				code: oauthCode,
				signature,
				grantType: "signature",
			};

			console.log("Token request body:", tokenBody);

			const tokenResponse = await fetch(
				"https://oauth2.manifoldxyz.dev/token",
				{
					method: "POST",
					headers: {
						"Content-Type": "application/json",
					},
					body: JSON.stringify(tokenBody),
				}
			);

			const tokenData = await tokenResponse.json();
			console.log("Token response:", tokenResponse.status, tokenData);

			if (!tokenResponse.ok) {
				throw new Error(
					`Token request failed: ${tokenResponse.status} - ${JSON.stringify(
						tokenData
					)}`
				);
			}

			const accessToken = tokenData.access_token;
			if (!accessToken) throw new Error("Failed to get access token");

			// Step 4: Exchange for session token (required by Studio API)
			const sessionResponse = await fetch(
				"https://studio.api.manifoldxyz.dev/auth/1/login",
				{
					method: "POST",
					headers: {
						Accept: "application/json",
						"Content-Type": "application/json",
						Authorization: `Bearer ${accessToken}`,
					},
					body: JSON.stringify({}),
				}
			);
			const sessionData = await sessionResponse.json();
			if (!sessionResponse.ok) {
				// Handle specific "User not found" error with friendly message
				if (sessionResponse.status === 400 && sessionData.error === "User not found") {
					throw new Error("User not registered with Manifold. Please register at studio.manifold.xyz first.");
				}
				throw new Error(
					`Session request failed: ${sessionResponse.status} - ${JSON.stringify(
						sessionData
					)}`
				);
			}
			const sessionToken = sessionData.token as string;
			if (!sessionToken) throw new Error("Failed to get session token");

			// Save tokens to cookies with 1-hour expiration
			const expiresAt = Date.now() + 60 * 60 * 1000; // 1 hour from now
			setCookie(COOKIE_NAMES.ACCESS_TOKEN, accessToken, 1);
			setCookie(COOKIE_NAMES.SESSION_TOKEN, sessionToken, 1);
			setCookie(COOKIE_NAMES.EXPIRES_AT, expiresAt.toString(), 1);

			setToken(accessToken);
			setSession(sessionToken);
			setAuthenticatedAddress(address);
			return { token: accessToken, session: sessionToken };
		} catch (error) {
			console.error("Manifold authentication error:", error);
			throw error;
		} finally {
			setIsAuthenticating(false);
		}
	};

	const logout = () => {
		clearAuthCookies();
		setToken("");
		setSession("");
		setAuthenticatedAddress(null);
	};

	return {
		token,
		session,
		isAuthenticated: !!(token && session && authenticatedAddress === address),
		isAuthenticating,
		authenticate,
		logout,
	};
}

// PKCE helpers
function generateCodeVerifier() {
	const array = new Uint8Array(32);
	crypto.getRandomValues(array);
	return btoa(String.fromCharCode(...array))
		.replace(/\+/g, "-")
		.replace(/\//g, "_")
		.replace(/=/g, "");
}

async function generateCodeChallenge(verifier: string) {
	const encoder = new TextEncoder();
	const data = encoder.encode(verifier);
	const digest = await crypto.subtle.digest("SHA-256", data);
	return btoa(String.fromCharCode(...new Uint8Array(digest)))
		.replace(/\+/g, "-")
		.replace(/\//g, "_")
		.replace(/=/g, "");
}
