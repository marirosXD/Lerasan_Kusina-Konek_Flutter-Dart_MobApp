# Kusina Konek

Kusina Konek is a Flutter and Supabase community app for sharing Filipino recipes, discussing cooking experiences, and discovering recipes based on saved and liked tags.

## Architecture

The app follows a lightweight Clean Architecture layout:

- `lib/core`: shared app constants and UI configuration.
- `lib/data`: Supabase data sources, JSON models, and repository implementations.
- `lib/domain`: recipe entities and feed recommendation logic.
- `lib/presentation`: login/signup, feed, recipe editor, recipe details, and profile screens.

The feed recommendation engine ranks recipes with cosine similarity over tags from a user's recorded likes, comments, and saves. New users see the latest recipes first.

## Supabase setup

1. Create a Supabase project.
2. In **SQL Editor**, run [`supabase/schema.sql`](supabase/schema.sql). It creates the app tables, row-level security policies, the public recipe image bucket, realtime publication entries, signup profile trigger, and secure like-count RPC.
3. Confirm **Authentication > Providers > Email** is enabled. Set email confirmation according to the demo flow you want; when confirmation is required, users must confirm before they can sign in.
4. Configure the Flutter app's Supabase project URL and publishable/anon key in `lib/main.dart`. Never put a service-role key in the client app.
5. Run the Flutter app on a device or emulator, create an account, post a recipe, then try likes, comments, collections, and profile editing.

Recipe photos are stored in the `recipe_images` bucket. The bucket is public for image display; uploads require an authenticated user.

## JWT feed error

`PGRST303` means PostgREST could not validate the JWT claims. Use **Refresh feed** in the app to renew the session; if it still fails, sign out and back in. If a newly issued token still reports an `iat` time in the future, the Supabase project has an Auth/API clock or signing configuration issue that must be corrected in the project or with Supabase support; the Flutter client cannot safely override JWT validation. [Supabase documents PGRST303 as a JWT claims validation/parsing error.](https://supabase.com/docs/guides/api/rest/postgrest-error-codes)

## Current feature boundaries

- Recipe posts currently have one photo and a combined cooking instructions/notes field. Multiple photo reordering and offline draft sync are not yet implemented.
- Recommendations are tag-based similarity, a lightweight explainable academic implementation rather than an external generative-AI service.
- Configure the project schema before presenting the app; the mobile client cannot create or repair Supabase database objects by itself.
