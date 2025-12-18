import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")! // REQUIRED
  );

  const now = new Date().toISOString();

  // 1️⃣ Get expired stories
  const { data: expired, error } = await supabase
    .from("story_cleanup")
    .select("*")
    .lte("expires_at", now);

  if (error) {
    return new Response("DB error", { status: 500 });
  }

  for (const row of expired ?? []) {
    // 2️⃣ Delete storage file
    await supabase.storage
      .from("stories_media")
      .remove([row.storage_path]);

    // 3️⃣ Delete Firestore doc via REST (optional, explained below)
    // OR rely on Firestore TTL (recommended)

    // 4️⃣ Remove cleanup row
    await supabase
      .from("story_cleanup")
      .delete()
      .eq("id", row.id);
  }

  return new Response("Cleanup done", { status: 200 });
});
