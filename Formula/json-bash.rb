class JsonBash < Formula
  desc "Load, Dump and Manipulate JSON in Bash"
  homepage "https://github.com/ingydotnet/json-bash"

  stable do
    url "https://github.com/ingydotnet/json-bash/archive/0.0.2.tar.gz"
    sha256 "b7867be8088618ea9b801f12fdac0e3e98187aadd82225baf6fd687590a38348"
    patch :DATA
  end

  def install
    system "make", "install", "PREFIX=#{prefix}"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test json-bash`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
__END__
diff --git a/Makefile b/Makefile
index 596be53..b1809e8 100644
--- a/Makefile
+++ b/Makefile
@@ -26,7 +26,7 @@ test: $(TEST_MORE)
 install: $(INSTALL_LIB)
 	install -m 0755 lib/$(CMD) $(INSTALL_LIB)/
 	install -c -d -m 0755 $(INSTALL_MAN)/
-	install -c -m 0644 man/man1/$(CMD).1 $(INSTALL_MAN)/
+	install -c -m 0644 man/man1/json.1 $(INSTALL_MAN)/
 
 uninstall:
 	rm -f $(INSTALL_LIB)/$(CMD)
