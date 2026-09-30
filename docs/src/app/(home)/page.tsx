import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { BookOpen, CodeXml } from 'lucide-react';
import { buttonVariants } from 'fumadocs-ui/components/ui/button';

export default function HomePage() {
  return (
    <div className="flex flex-col justify-center text-center flex-1">
      <h1 className="text-5xl font-bold mb-1">Aperture</h1>
      <h3 className="text-2x1 text-neutral-500 mb-8">Artifical Intelligence Enabled Wifi Imaging</h3>
      <div className="flex flex-wrap items-center justify-center gap-2 md:flex-col">
        <Link href="/docs" className={buttonVariants({variant: "secondary", size: "icon"})}>
          <BookOpen /> <span className='px-2'>Documentation</span>
        </Link>
        <Link href="https://github.com/arnav57/aperture" className={buttonVariants({variant: "secondary", size: "icon"})}
        target='_blank' rel="noopener noreferrer">
          <CodeXml /> <span className="px-4">Source Code</span>
        </Link>
      </div>
    </div>
  );
}
