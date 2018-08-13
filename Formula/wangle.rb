class Wangle < Formula
  desc "Wangle is a framework providing a set of common client/server abstractions for building services in a consistent, modular, and composable way."
  homepage "https://github.com/facebook/wangle"
  url "https://github.com/facebook/wangle/archive/v2018.08.06.00.tar.gz"
  sha256 "85028a9917b83638525d4a0146b00b61da944a01488cd248331e483f0496676f"
   depends_on "cmake" => :build
   depends_on "folly"
   depends_on "openssl"

  def install
    cd "wangle"
    system "cmake", ".", *std_cmake_args
    system "make", "install"
  end

  test do
    system "false"
  end
end
