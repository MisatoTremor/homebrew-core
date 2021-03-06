class Emscripten < Formula
  desc "LLVM bytecode to JavaScript compiler"
  homepage "https://kripken.github.io/emscripten-site/"

  stable do
    url "https://github.com/kripken/emscripten/archive/1.37.40.tar.gz"
    sha256 "40d8a095c510e5e5e2032131e0dc5d38f996172deb0415588b702146d1ea8bd5"

    resource "fastcomp" do
      url "https://github.com/kripken/emscripten-fastcomp/archive/1.37.40.tar.gz"
      sha256 "92802053b8229adfbc14a1c4efb22fd7da9b18b4157c64e4f321ea59afbd2e09"
    end

    resource "fastcomp-clang" do
      url "https://github.com/kripken/emscripten-fastcomp-clang/archive/1.37.40.tar.gz"
      sha256 "3977e9358a5e716d11fa912a3f63ffb80fd110161a2027da0a2d58ee25f2aed5"
    end
  end

  bottle do
    cellar :any
    sha256 "3d13b47920d34f5e0485248bcd5cb0ddde3eade2edacd91bbbef2514d2dd233e" => :high_sierra
    sha256 "87e13523a66404fbaebd7a492e6a57e44e84281e2f355f38b502fe4ffa736669" => :sierra
    sha256 "9fcf6878c55c2d40b16201e8050f0a0a4eaf801cbf9d310e61556cbc013161d9" => :el_capitan
  end

  head do
    url "https://github.com/kripken/emscripten.git", :branch => "master"

    resource "fastcomp" do
      url "https://github.com/kripken/emscripten-fastcomp.git", :branch => "master"
    end

    resource "fastcomp-clang" do
      url "https://github.com/kripken/emscripten-fastcomp-clang.git", :branch => "master"
    end
  end

  needs :cxx11

  depends_on "python@2"
  depends_on "cmake" => :build
  depends_on "node"
  depends_on "closure-compiler" => :optional
  depends_on "yuicompressor"

  def install
    ENV.cxx11
    # rewrite hardcoded paths from system python to homebrew python
    python2_shebangs = `grep --recursive --files-with-matches ^#!/usr/bin/python #{buildpath}`
    python2_shebang_files = python2_shebangs.lines.sort.uniq
    python2_shebang_files.map! { |f| Pathname(f.chomp) }
    python2_shebang_files.reject! &:symlink?
    inreplace python2_shebang_files, %r{^#!/usr/bin/python2?$}, "#!#{Formula["python@2"].opt_bin}/python2"

    # All files from the repository are required as emscripten is a collection
    # of scripts which need to be installed in the same layout as in the Git
    # repository.
    libexec.install Dir["*"]

    (buildpath/"fastcomp").install resource("fastcomp")
    (buildpath/"fastcomp/tools/clang").install resource("fastcomp-clang")

    cmake_args = std_cmake_args.reject { |s| s["CMAKE_INSTALL_PREFIX"] }
    cmake_args = [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_PREFIX=#{libexec}/llvm",
      "-DLLVM_TARGETS_TO_BUILD='X86;JSBackend'",
      "-DLLVM_INCLUDE_EXAMPLES=OFF",
      "-DLLVM_INCLUDE_TESTS=OFF",
      "-DCLANG_INCLUDE_TESTS=OFF",
      "-DOCAMLFIND=/usr/bin/false",
      "-DGO_EXECUTABLE=/usr/bin/false",
    ]

    mkdir "fastcomp/build" do
      system "cmake", "..", *cmake_args
      system "make"
      system "make", "install"
    end

    %w[em++ em-config emar emcc emcmake emconfigure emlink.py emmake
       emranlib emrun emscons].each do |emscript|
      bin.install_symlink libexec/emscript
    end
  end

  def caveats; <<~EOS
    Manually set LLVM_ROOT to
      #{opt_libexec}/llvm/bin
    and comment out BINARYEN_ROOT
    in ~/.emscripten after running `emcc` for the first time.
    EOS
  end

  test do
    system bin/"emcc"
    assert_predicate testpath/".emscripten", :exist?, "Failed to create sample config"
  end
end
