source "https://rubygems.org"

# Match the gem set GitHub Pages uses to build this site.
# Keep in step with https://pages.github.com/versions/
# (currently github-pages 232, Jekyll 3.10.0, Ruby 3.3.4).
gem "github-pages", "~> 232", group: :jekyll_plugins

group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-gist"
  gem "jekyll-include-cache"
  gem "jekyll-paginate"
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jemoji"
  # https://github.com/jekyll/jekyll/issues/8523
  gem "webrick"
end

# Only a transitive dependency, but floored so the lockfile cannot resolve to
# versions affected by the 2025-2026 Nokogiri/libxml2 advisories.
gem "nokogiri", ">= 1.19.5"

# Windows and JRuby do not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.2", :platforms => [:mingw, :x64_mingw, :mswin]
