import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import {themes as prismThemes} from 'prism-react-renderer';

const config: Config = {
  title: 'Huri',
  tagline: 'Documentation fonctionnelle, technique et opérationnelle',
  favicon: 'img/huri.webp',
  url: 'https://huri-jet.vercel.app',
  baseUrl: '/',
  organizationName: 'Pacific-knowledge-LLC',
  projectName: 'Huri',
  onBrokenLinks: 'throw',
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  future: {
    v4: true,
  },
  i18n: {
    defaultLocale: 'fr',
    locales: ['fr'],
  },
  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/Pacific-knowledge-LLC/Huri/edit/main/docs/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],
  themeConfig: {
    image: 'img/huri.webp',
    colorMode: {
      defaultMode: 'light',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Huri',
      logo: {
        alt: 'Icône Huri',
        src: 'img/huri.webp',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docs',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://huri-jet.vercel.app',
          label: 'Télécharger Huri',
          position: 'right',
        },
        {
          href: 'https://github.com/Pacific-knowledge-LLC/Huri',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Produit',
          items: [
            {label: 'Fonctionnalités', to: '/functional/features'},
            {label: 'Architecture', to: '/technical/architecture'},
          ],
        },
        {
          title: 'Exploitation',
          items: [
            {label: 'Release', to: '/technical/release'},
            {label: 'Secrets', to: '/technical/secrets'},
            {label: 'Validation', to: '/technical/validation'},
          ],
        },
        {
          title: 'Liens',
          items: [
            {
              label: 'Application',
              href: 'https://huri-jet.vercel.app',
            },
            {
              label: 'Code source',
              href: 'https://github.com/Pacific-knowledge-LLC/Huri',
            },
          ],
        },
      ],
      copyright: `© ${new Date().getFullYear()} Pacific Knowledge. Licence MIT.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
