describe "fastlane.gemspec" do
  let(:specification) { Gem::Specification.load("fastlane.gemspec") }

  it "requires a jwt version with current security fixes" do
    jwt_dependency = specification.dependencies.find { |dependency| dependency.name == "jwt" }

    expect(jwt_dependency).not_to be_nil
    expect(jwt_dependency.requirement.satisfied_by?(Gem::Version.new("3.2.0"))).to be(true)
    expect(jwt_dependency.requirement.satisfied_by?(Gem::Version.new("3.1.2"))).to be(false)
  end
end
