# Milkyware Blog Repository

This is a GitHub Pages blog using Jekyll with the Minimal Mistakes theme.

## Blog Conventions

- Posts are located in `_posts/` directory with filename format: `YYYY-MM-DD-title.md`
- In progress posts should be created in the `_drafts/` folder
- Each post uses Jekyll frontmatter with:
  - `title`: Post title
  - `category`: Optional category (e.g., .NET, Automation)
  - `tags`: List of relevant tags (preferred over category)
- Writing style is technical and instructional with code samples
- Posts often include personal experience and lessons learned
- Structure typically: problem statement → solution approach → code examples → conclusion
- All spelling and grammar should be British English

## Development

### Local Setup

1. Install Ruby and Bundler
2. Run `bundle install` to install dependencies
3. Start development server with `bundle exec jekyll serve`

### Building

- Production build: `bundle exec jekyll build`
- Output goes to `_site/` directory

### Writing New Posts

1. Create new file in `_posts/` with date-prefixed name
2. Include required frontmatter (title, optional category/tags)
3. Write content in markdown format
4. Use standard markdown syntax for formatting

## Repository Structure

- `_posts/` - Blog posts in markdown format
- `_pages/` - Static pages (archive, sitemap, etc.)
- `assets/` - CSS, JavaScript, images
- `_config.yml` - Jekyll configuration
- `README.md` - Brief repository description

## Important Notes

- The blog uses the Minimal Mistakes theme via remote_theme
- Comments are handled by Utterances (GitHub-based)
- Google Analytics is configured for tracking
- Permalinks follow `/categories/:title/` pattern
- Pagination is enabled (5 posts per page)
