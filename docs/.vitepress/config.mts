import { defineConfig } from "vitepress";

export default defineConfig({
	base: process.env.DOCS_BASE ?? "/",
	title: "AnimLayers",
	description: "Roblox animation clips on named layers of one Animator.",
	cleanUrls: true,
	themeConfig: {
		nav: [
			{ text: "AnimLayers", link: "/" },
			{ text: "Guides", link: "/guides/" },
			{ text: "API", link: "/api/" },
			{ text: "Architecture", link: "/architecture" },
		],
		sidebar: [
			{
				text: "AnimLayers",
				items: [
					{ text: "Overview", link: "/" },
					{ text: "Architecture", link: "/architecture" },
				],
			},
			{
				text: "Guides",
				items: [
					{ text: "Overview", link: "/guides/" },
					{ text: "Getting started", link: "/guides/getting-started" },
					{ text: "Migrating from 0.1", link: "/guides/migrating" },
					{ text: "The dev place", link: "/guides/dev-place" },
					{ text: "Verification", link: "/guides/verification" },
					{ text: "Studio verification", link: "/guides/studio-verification" },
				],
			},
			{
				text: "API",
				items: [
					{ text: "Entry and types", link: "/api/" },
					{ text: "layerController", link: "/api/layerController" },
					{ text: "clipDefinition", link: "/api/clipDefinition" },
				],
			},
			{
				text: "TODO",
				collapsed: true,
				items: [
					{ text: "TODO index", link: "/todo/" },
					{ text: "API assessment (VMMO-90)", link: "/todo/vmmo90/apiAssessment" },
					{ text: "Backlog", link: "/todo/backlog" },
				],
			},
		],
		search: {
			provider: "local",
		},
		outline: {
			level: [2, 3],
		},
		socialLinks: [{ icon: "github", link: "https://github.com/emdomanus/animLayers" }],
		editLink: {
			pattern: "https://github.com/emdomanus/animLayers/edit/main/docs/:path",
			text: "Edit this page on GitHub",
		},
	},
});
