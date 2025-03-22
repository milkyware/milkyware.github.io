source "https://rubygems.org"
# Hello! This is where you manage which Jekyll version is used to run.
# When you want to use a different version, change it below, save the
# file and run `bundle install`. Run Jekyll with `bundle exec`, like so:
#
#     bundle exec jekyll serve
#
# This will help ensure the proper Jekyll version is running.
# Happy Jekylling!
# gem "jekyll", "~> 4.3.1"
# This is the default theme for new Jekyll sites. You may change this to anything you like.
gem "jekyll-theme-clean-blog", "~> 4.0.12"
# If you want to use GitHub Pages, remove the "gem "jekyll"" above and
# uncomment the line below. To upgrade, run `bundle update github-pages`.
gem "github-pages", group: :jekyll_plugins
# If you have any plugins, put them here!
group :jekyll_plugins do
  gem "jekyll-algolia"
  gem "jekyll-feed"
  gem "jekyll-gist"
  gem "jekyll-include-cache"
  gem "jekyll-paginate"
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jemoji"
  # https://github.com/jekyll/jekyll/issues/8523
  gem "webrick"
  gem "nokogiri", "1.18.4"
end

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]
