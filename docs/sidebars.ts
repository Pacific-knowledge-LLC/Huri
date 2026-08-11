import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Fonctionnel',
      items: [
        'functional/context',
        'functional/personas',
        'functional/features',
      ],
    },
    {
      type: 'category',
      label: 'Technique',
      items: [
        'technical/architecture',
        'technical/data',
        'technical/patterns',
        'technical/release',
        'technical/secrets',
        'technical/validation',
      ],
    },
  ],
};

export default sidebars;
