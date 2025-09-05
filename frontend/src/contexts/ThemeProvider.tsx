import { useEffect } from "react";
import type { ReactNode } from "react";
import { ThemeContext } from "../hooks/useTheme";

interface ThemeProviderProps {
	children: ReactNode;
	isDarkMode: boolean;
	toggleTheme: () => void;
}

export function ThemeProvider({
	children,
	isDarkMode,
	toggleTheme,
}: ThemeProviderProps) {
	useEffect(() => {
		// Update body classes based on theme
		document.body.className = isDarkMode
			? "bg-zinc-950 text-zinc-100 font-mono"
			: "bg-zinc-50 text-zinc-900 font-mono";

		// Update color scheme
		document.documentElement.style.colorScheme = isDarkMode ? "dark" : "light";

		// Update CSS custom properties for theme-aware components
		const root = document.documentElement;
		if (isDarkMode) {
			root.style.setProperty("--card-bg", "#18181b"); // zinc-900
			root.style.setProperty("--card-border", "#27272a"); // zinc-800
			root.style.setProperty("--card-hover-bg", "#27272a"); // zinc-800
			root.style.setProperty("--card-hover-border", "#3f3f46"); // zinc-700
			root.style.setProperty("--input-bg", "#18181b"); // zinc-900
			root.style.setProperty("--input-border", "#3f3f46"); // zinc-700
			root.style.setProperty("--input-text", "#f4f4f5"); // zinc-100
			root.style.setProperty("--input-placeholder", "#a1a1aa"); // zinc-400
			root.style.setProperty("--label-text", "#d4d4d8"); // zinc-300
			root.style.setProperty("--help-text", "#a1a1aa"); // zinc-400
			root.style.setProperty("--btn-secondary-bg", "#27272a"); // zinc-800
			root.style.setProperty("--btn-secondary-text", "#f4f4f5"); // zinc-100
			root.style.setProperty("--btn-secondary-border", "#3f3f46"); // zinc-700
			root.style.setProperty("--btn-secondary-hover", "#3f3f46"); // zinc-700
			root.style.setProperty("--btn-primary-bg", "#f4f4f5"); // zinc-100
			root.style.setProperty("--btn-primary-text", "#18181b"); // zinc-900
			root.style.setProperty("--btn-primary-hover", "#e4e4e7"); // zinc-200
			root.style.setProperty("--btn-danger-bg", "#dc2626"); // red-600
			root.style.setProperty("--btn-danger-text", "#ffffff"); // white
			root.style.setProperty("--btn-danger-hover", "#b91c1c"); // red-700
			root.style.setProperty("--btn-ghost-text", "#a1a1aa"); // zinc-400
			root.style.setProperty("--btn-ghost-hover-text", "#f4f4f5"); // zinc-100
			root.style.setProperty("--btn-ghost-hover-bg", "#27272a"); // zinc-800
		} else {
			root.style.setProperty("--card-bg", "#ffffff"); // white
			root.style.setProperty("--card-border", "#e4e4e7"); // zinc-300
			root.style.setProperty("--card-hover-bg", "#f4f4f5"); // zinc-100
			root.style.setProperty("--card-hover-border", "#d4d4d8"); // zinc-300
			root.style.setProperty("--input-bg", "#ffffff"); // white
			root.style.setProperty("--input-border", "#d4d4d8"); // zinc-300
			root.style.setProperty("--input-text", "#18181b"); // zinc-900
			root.style.setProperty("--input-placeholder", "#71717a"); // zinc-500
			root.style.setProperty("--label-text", "#3f3f46"); // zinc-700
			root.style.setProperty("--help-text", "#71717a"); // zinc-500
			root.style.setProperty("--btn-secondary-bg", "#e4e4e7"); // zinc-200 - darker background for better readability
			root.style.setProperty("--btn-secondary-text", "#18181b"); // zinc-900
			root.style.setProperty("--btn-secondary-border", "#d4d4d8"); // zinc-300
			root.style.setProperty("--btn-secondary-hover", "#d4d4d8"); // zinc-300
			root.style.setProperty("--btn-primary-bg", "#18181b"); // zinc-900 - dark button in light mode
			root.style.setProperty("--btn-primary-text", "#f4f4f5"); // zinc-100 - light text on dark button
			root.style.setProperty("--btn-primary-hover", "#27272a"); // zinc-800
			root.style.setProperty("--btn-danger-bg", "#dc2626"); // red-600
			root.style.setProperty("--btn-danger-text", "#ffffff"); // white
			root.style.setProperty("--btn-danger-hover", "#b91c1c"); // red-700
			root.style.setProperty("--btn-ghost-text", "#71717a"); // zinc-500
			root.style.setProperty("--btn-ghost-hover-text", "#18181b"); // zinc-900
			root.style.setProperty("--btn-ghost-hover-bg", "#f4f4f5"); // zinc-100
		}
	}, [isDarkMode]);

	return (
		<ThemeContext.Provider value={{ isDarkMode, toggleTheme }}>
			{children}
		</ThemeContext.Provider>
	);
}
