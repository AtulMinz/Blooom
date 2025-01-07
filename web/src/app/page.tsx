"use client";
import { TextEffect } from "@/components/ui/text-effect";
import { ConnectKitButton } from "connectkit";

export default function Home() {
  return (
    <div>
      <ConnectKitButton />
      <TextEffect className="animate transition duration-4">
        bloom your habits
      </TextEffect>
    </div>
  );
}
