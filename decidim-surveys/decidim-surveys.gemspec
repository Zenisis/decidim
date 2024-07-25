# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "decidim/surveys/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.version = Decidim::Surveys.version
  s.authors = ["Josep Jaume Rey Peroy", "Marc Riera Casals", "Oriol Gual Oliva"]
  s.email = ["josepjaume@gmail.com", "mrc2407@gmail.com", "oriolgual@gmail.com"]
  s.license = "AGPL-3.0"
  s.homepage = "https://decidim.org"
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/decidim/decidim/issues",
    "documentation_uri" => "https://docs.decidim.org/",
    "funding_uri" => "https://opencollective.com/decidim",
    "homepage_uri" => "https://decidim.org",
    "source_code_uri" => "https://github.com/decidim/decidim"
  }
  s.required_ruby_version = "~> 3.3.0"

  s.name = "decidim-surveys"
  s.summary = "Decidim surveys module"
  s.description = "A surveys component for decidim's participatory spaces."

  s.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w(app/ config/ db/ lib/ Rakefile README.md))
    end
  end

  s.add_dependency "decidim-core", Decidim::Surveys.version
  s.add_dependency "decidim-forms", Decidim::Surveys.version

  s.add_development_dependency "decidim-admin", Decidim::Surveys.version
  s.add_development_dependency "decidim-dev", Decidim::Surveys.version
  s.add_development_dependency "decidim-participatory_processes", Decidim::Surveys.version
  s.add_development_dependency "decidim-templates", Decidim::Surveys.version
end