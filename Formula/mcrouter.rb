class Mcrouter < Formula
  desc "Mcrouter is a memcached protocol router for scaling memcached deployments."
  homepage "https://github.com/facebook/mcrouter"
  version "0.38.0"
  url "https://github.com/facebook/mcrouter/archive/v#{version}-release.tar.gz"
  sha256 "d51c432e91106e1d030daddb5b43b02563a2f8ff34e08b9a9dd84f18c4604346"
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "ragel" => :build
  depends_on "glog"
  depends_on "boost"
  depends_on "double-conversion"
  depends_on "wangle"
  depends_on "folly"
  depends_on "libinotify-kqueue"

  needs :cxx14
  patch :p1, :DATA

  fails_with :clang do
    build 900
    cause "no matching function for call to 'min'"
  end

  fails_with :gcc_4_0
  fails_with :gcc
  ("4.3".."4.9").each do |n|
    fails_with :gcc => n do
      cause '*** A compiler with support for C++14 language features is required.'
    end
  end

  def install
    cd "mcrouter" do
      system "./autogen.sh"
      system "./configure", "--disable-debug",
                            "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--prefix=#{prefix}",
                            "CXX=#{ENV.cxx}",
                            "CC=#{ENV.cc}"
      system "make", "install"
    end
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test mcrouter`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
__END__
diff --git a/mcrouter/Makefile.am b/mcrouter/Makefile.am
index b40f5483..9de50c61 100644
--- a/mcrouter/Makefile.am
+++ b/mcrouter/Makefile.am
@@ -200,7 +200,7 @@ mcrouter_SOURCES = \
 
 libmcroutercore_a_CPPFLAGS = -I..
 
-mcrouter_LDADD = libmcroutercore.a lib/libmcrouter.a -lfolly -lfollylogging
+mcrouter_LDADD = libmcroutercore.a lib/libmcrouter.a -lfolly -lwangle -linotify
 mcrouter_CPPFLAGS = -I..
 
 clean-local:
diff --git a/mcrouter/configure.ac b/mcrouter/configure.ac
index 1b4522d7..794e9d67 100644
--- a/mcrouter/configure.ac
+++ b/mcrouter/configure.ac
@@ -112,13 +112,13 @@ AC_CHECK_LIB([z], [gzread], [], [AC_MSG_ERROR([Unable to find zlib])])
 AC_CHECK_LIB([double-conversion],[ceil],[],[AC_MSG_ERROR(
              [Please install double-conversion library])])
 AC_CHECK_LIB([dl], [dlopen], [])
-AC_CHECK_LIB([folly],[follyinit],[follylogging],[getenv],[],[AC_MSG_ERROR(
+AC_CHECK_LIB([folly],[getenv],[],[AC_MSG_ERROR(
              [Please install the folly library])])
 AC_CHECK_HEADER([folly/Likely.h], [], [AC_MSG_ERROR(
 [Couldn't find folly, please download from https://github.com/facebook/folly]
 )], [])
-AC_CHECK_LIB([wangle], [getenv], [], [AC_MSG_ERROR(
-             [Please install the wangle library])])
+#AC_CHECK_LIB([wangle], [getenv], [], [AC_MSG_ERROR(
+#             [Please install the wangle library])])
 
 # Checks for typedefs, structures, and compiler characteristics.
 AC_HEADER_STDBOOL
diff --git a/mcrouter/lib/Lz4Immutable.cpp b/mcrouter/lib/Lz4Immutable.cpp
index ce4d13fb..2bd20214 100644
--- a/mcrouter/lib/Lz4Immutable.cpp
+++ b/mcrouter/lib/Lz4Immutable.cpp
@@ -117,7 +117,7 @@ void safeCopy(uint8_t* dest, IovecCursor& source, size_t count) {
   int64_t left = count;
   uint64_t src;
   do {
-    size_t toWrite = std::min(8l, left);
+    size_t toWrite = std::min<int>(8l, left);
     if (LIKELY(toWrite == sizeof(uint64_t))) {
       src = source.peek<uint64_t>();
     } else {
diff --git a/mcrouter/lib/Makefile.am b/mcrouter/lib/Makefile.am
index 929bc6d2..916fca2f 100644
--- a/mcrouter/lib/Makefile.am
+++ b/mcrouter/lib/Makefile.am
@@ -91,7 +91,7 @@ libmcrouter_a_SOURCES = \
   debug/Fifo.h \
   debug/FifoManager.cpp \
   debug/FifoManager.h \
-  fbi/counting_sem.c \
+  fbi/counting_sem.cpp \
   fbi/counting_sem.h \
   fbi/cpp/FuncGenerator.h \
   fbi/cpp/LogFailure.cpp \
@@ -113,7 +113,7 @@ libmcrouter_a_SOURCES = \
   fbi/network.c \
   fbi/network.h \
   fbi/queue.h \
-  fbi/sfrlock.c \
+  fbi/sfrlock.cpp \
   fbi/sfrlock.h \
   fbi/time.h \
   fbi/util.h \
@@ -218,4 +218,4 @@ check_PROGRAMS =
 
 libtestmain_la_CPPFLAGS = -Igtest/include -Igtest
 libtestmain_la_SOURCES = TestMain.cpp gtest/src/gtest-all.cc
-libtestmain_la_LIBADD = -lfolly -lfollyinit
+libtestmain_la_LIBADD = -lfolly
diff --git a/mcrouter/lib/config/ConfigPreprocessor.cpp b/mcrouter/lib/config/ConfigPreprocessor.cpp
index 72c36ef9..5c8f3697 100644
--- a/mcrouter/lib/config/ConfigPreprocessor.cpp
+++ b/mcrouter/lib/config/ConfigPreprocessor.cpp
@@ -821,7 +821,7 @@ class ConfigPreprocessor::BuiltIns {
     } else if (dict.isArray()) {
       dynamic res = dynamic::array;
       checkLogic(from.isInt() && to.isInt(), "Slice: from/to is not an int");
-      auto fromId = std::max(0L, from.asInt());
+      auto fromId = std::max<int>(0L, from.asInt());
       auto toId = std::min(to.asInt() + 1, (int64_t)dict.size());
       for (auto i = fromId; i < toId; ++i) {
         res.push_back(std::move(dict[i]));
@@ -831,7 +831,7 @@ class ConfigPreprocessor::BuiltIns {
       string res;
       auto dictStr = dict.stringPiece();
       checkLogic(from.isInt() && to.isInt(), "Slice: from/to is not an int");
-      auto fromId = std::max(0L, from.asInt());
+      auto fromId = std::max<int>(0L, from.asInt());
       auto toId = std::min(to.asInt() + 1, (int64_t)dict.size());
       for (auto i = fromId; i < toId; ++i) {
         res += dictStr[i];
diff --git a/mcrouter/lib/config/test/Makefile.am b/mcrouter/lib/config/test/Makefile.am
index 137c3ab1..3f69805a 100644
--- a/mcrouter/lib/config/test/Makefile.am
+++ b/mcrouter/lib/config/test/Makefile.am
@@ -11,6 +11,4 @@ mcrouter_config_test_CPPFLAGS = \
 
 mcrouter_config_test_LDADD = \
   $(top_builddir)/lib/libmcrouter.a \
-  $(top_builddir)/lib/libtestmain.la \
-	-lfollylogging \
-	-lfollyinit
+  $(top_builddir)/lib/libtestmain.la
diff --git a/mcrouter/lib/fbi/counting_sem.c b/mcrouter/lib/fbi/counting_sem.c
deleted file mode 100644
index 4b43da73..00000000
--- a/mcrouter/lib/fbi/counting_sem.c
+++ /dev/null
@@ -1,146 +0,0 @@
-/*
- *  Copyright (c) 2016, Facebook, Inc.
- *
- *  This source code is licensed under the MIT license found in the LICENSE
- *  file in the root directory of this source tree.
- *
- */
-#include "counting_sem.h"
-
-#include <limits.h>
-#include <linux/futex.h>
-#include <stdbool.h>
-#include <stdint.h>
-#include <sys/syscall.h>
-#include <unistd.h>
-
-#include "mcrouter/lib/fbi/util.h"
-
-#define fbi_futex_wait(p, val)                                          \
-  syscall(SYS_futex, (p), FUTEX_WAIT | FUTEX_PRIVATE_FLAG, (val),       \
-          NULL, NULL, 0);
-
-#define fbi_futex_wake(p, n)                                            \
-  syscall(SYS_futex, (p), FUTEX_WAKE | FUTEX_PRIVATE_FLAG, (n),         \
-          NULL, NULL, 0);
-
-#define MIN(a, b) ((a) <= (b) ? (a) : (b))
-#define MAX(a, b) ((a) >= (b) ? (a) : (b))
-
-void counting_sem_init(counting_sem_t* sem, int32_t val) {
-  sem->cnt = MAX(val, 0);
-}
-
-int32_t counting_sem_value(counting_sem_t* sem) {
-  int32_t cnt = ACCESS_ONCE(sem->cnt);
-  return MAX(cnt, 0);
-}
-
-static int32_t counting_sem_lazy_helper(counting_sem_t* sem, int32_t n,
-                                        bool nonblocking) {
-  int32_t latest, prev, attempt, next;
-
-  if (n <= 0) {
-    return 0;
-  }
-
-  /*
-   * Non-blocking case: semaphore value is positive.
-   * Decrement it by at most n and return right away.
-   */
-  latest = ACCESS_ONCE(sem->cnt);
-  while (latest > 0) {
-    prev = latest;
-    attempt = MIN(n, prev);
-    latest = __sync_val_compare_and_swap(&sem->cnt, prev, prev - attempt);
-    if (latest == prev) {
-      return attempt;
-    }
-  }
-
-  if (nonblocking) {
-    return 0;
-  }
-
-  /*
-   * Otherwise we have to wait and try again.
-   */
-  do {
-
-    /* Wait loop */
-    do {
-      /*
-       * Change 0 into -1.  Note we must do this check
-       * every loop iteration due to the following scenario:
-       * This thread sets -1.  Before we called wait, another thread
-       * posts() and yet another thread waits() so the counter is back to 0.
-       */
-      if (latest == 0) {
-        latest = __sync_val_compare_and_swap(&sem->cnt, 0, -1);
-      }
-
-      if (latest <= 0) {
-        /*
-         * Either we saw a 0 (and we set it to -1) or we saw a -1.
-         * Wait if it's still a -1.
-         */
-        fbi_futex_wait(&sem->cnt, -1);
-        latest = ACCESS_ONCE(sem->cnt);
-      }
-    } while (latest <= 0);
-
-    /* latest > 0 due to loop above, so attempt is always positive */
-    prev = latest;
-    attempt = MIN(n, prev);
-    next = prev - attempt;
-
-    /*
-     * Other threads might already be waiting.
-     * We can't set this to 0 here, or post() will never wake them up.
-     */
-    if (next == 0) {
-      next = -1;
-    }
-    latest = __sync_val_compare_and_swap(&sem->cnt, prev, next);
-  } while (latest != prev);
-
-  if (next > 0) {
-    /*
-     * The semaphore value is still positive.
-     * We must wake here in case other threads are waiting.
-     */
-    fbi_futex_wake(&sem->cnt, 1);
-  }
-
-  return attempt;
-}
-
-int32_t counting_sem_lazy_wait(counting_sem_t* sem, int32_t n) {
-  return counting_sem_lazy_helper(sem, n, false);
-}
-
-int32_t counting_sem_lazy_nonblocking(counting_sem_t* sem, int32_t n) {
-  return counting_sem_lazy_helper(sem, n, true);
-}
-
-
-void counting_sem_post(counting_sem_t* sem, int32_t n) {
-  int32_t latest, prev, base, next;
-
-  if (n <= 0) {
-    return;
-  }
-
-  latest = ACCESS_ONCE(sem->cnt);
-  do {
-    prev = latest;
-    base = MAX(prev, 0);
-    next = base + MIN(n, INT32_MAX - base);
-    latest = __sync_val_compare_and_swap(&sem->cnt, prev, next);
-  } while (latest != prev);
-
-  if (prev < 0) {
-    /* If we went out of the negative state, we need to wake a thread up. */
-    fbi_futex_wake(&sem->cnt, 1);
-  }
-}
diff --git a/mcrouter/lib/fbi/counting_sem.cpp b/mcrouter/lib/fbi/counting_sem.cpp
new file mode 100644
index 00000000..631579e3
--- /dev/null
+++ b/mcrouter/lib/fbi/counting_sem.cpp
@@ -0,0 +1,146 @@
+/*
+ *  Copyright (c) 2016, Facebook, Inc.
+ *
+ *  This source code is licensed under the MIT license found in the LICENSE
+ *  file in the root directory of this source tree.
+ *
+ */
+#include "counting_sem.h"
+
+#include <limits.h>
+#include <folly/detail/Futex.h>
+#include <stdbool.h>
+#include <stdint.h>
+#include <sys/syscall.h>
+#include <unistd.h>
+
+#include "mcrouter/lib/fbi/util.h"
+
+#define fbi_futex_wait(p, val)                                          \
+  folly::detail::Futex<std::atomic> f(*p);                                      \
+  f.futexWait(val);
+
+#define fbi_futex_wake(p, n)                                            \
+  folly::detail::Futex<std::atomic> f(*p);                                      \
+  f.futexWake(n);
+
+#define MIN(a, b) ((a) <= (b) ? (a) : (b))
+#define MAX(a, b) ((a) >= (b) ? (a) : (b))
+
+void counting_sem_init(counting_sem_t* sem, int32_t val) {
+  sem->cnt = MAX(val, 0);
+}
+
+int32_t counting_sem_value(counting_sem_t* sem) {
+  int32_t cnt = ACCESS_ONCE(sem->cnt);
+  return MAX(cnt, 0);
+}
+
+static int32_t counting_sem_lazy_helper(counting_sem_t* sem, int32_t n,
+                                        bool nonblocking) {
+  int32_t latest, prev, attempt, next;
+
+  if (n <= 0) {
+    return 0;
+  }
+
+  /*
+   * Non-blocking case: semaphore value is positive.
+   * Decrement it by at most n and return right away.
+   */
+  latest = ACCESS_ONCE(sem->cnt);
+  while (latest > 0) {
+    prev = latest;
+    attempt = MIN(n, prev);
+    latest = __sync_val_compare_and_swap(&sem->cnt, prev, prev - attempt);
+    if (latest == prev) {
+      return attempt;
+    }
+  }
+
+  if (nonblocking) {
+    return 0;
+  }
+
+  /*
+   * Otherwise we have to wait and try again.
+   */
+  do {
+
+    /* Wait loop */
+    do {
+      /*
+       * Change 0 into -1.  Note we must do this check
+       * every loop iteration due to the following scenario:
+       * This thread sets -1.  Before we called wait, another thread
+       * posts() and yet another thread waits() so the counter is back to 0.
+       */
+      if (latest == 0) {
+        latest = __sync_val_compare_and_swap(&sem->cnt, 0, -1);
+      }
+
+      if (latest <= 0) {
+        /*
+         * Either we saw a 0 (and we set it to -1) or we saw a -1.
+         * Wait if it's still a -1.
+         */
+        fbi_futex_wait(&sem->cnt, -1);
+        latest = ACCESS_ONCE(sem->cnt);
+      }
+    } while (latest <= 0);
+
+    /* latest > 0 due to loop above, so attempt is always positive */
+    prev = latest;
+    attempt = MIN(n, prev);
+    next = prev - attempt;
+
+    /*
+     * Other threads might already be waiting.
+     * We can't set this to 0 here, or post() will never wake them up.
+     */
+    if (next == 0) {
+      next = -1;
+    }
+    latest = __sync_val_compare_and_swap(&sem->cnt, prev, next);
+  } while (latest != prev);
+
+  if (next > 0) {
+    /*
+     * The semaphore value is still positive.
+     * We must wake here in case other threads are waiting.
+     */
+    fbi_futex_wake(&sem->cnt, 1);
+  }
+
+  return attempt;
+}
+
+int32_t counting_sem_lazy_wait(counting_sem_t* sem, int32_t n) {
+  return counting_sem_lazy_helper(sem, n, false);
+}
+
+int32_t counting_sem_lazy_nonblocking(counting_sem_t* sem, int32_t n) {
+  return counting_sem_lazy_helper(sem, n, true);
+}
+
+
+void counting_sem_post(counting_sem_t* sem, int32_t n) {
+  int32_t latest, prev, base, next;
+
+  if (n <= 0) {
+    return;
+  }
+
+  latest = ACCESS_ONCE(sem->cnt);
+  do {
+    prev = latest;
+    base = MAX(prev, 0);
+    next = base + MIN(n, INT32_MAX - base);
+    latest = __sync_val_compare_and_swap(&sem->cnt, prev, next);
+  } while (latest != prev);
+
+  if (prev < 0) {
+    /* If we went out of the negative state, we need to wake a thread up. */
+    fbi_futex_wake(&sem->cnt, 1);
+  }
+}
diff --git a/mcrouter/lib/fbi/cpp/test/Makefile.am b/mcrouter/lib/fbi/cpp/test/Makefile.am
index 03199af6..e02d7768 100644
--- a/mcrouter/lib/fbi/cpp/test/Makefile.am
+++ b/mcrouter/lib/fbi/cpp/test/Makefile.am
@@ -10,6 +10,4 @@ mcrouter_fbi_cpp_test_CPPFLAGS = \
 
 mcrouter_fbi_cpp_test_LDADD = \
   $(top_builddir)/lib/libmcrouter.a \
-  $(top_builddir)/lib/libtestmain.la \
-	-lfollylogging \
-	-lfollyinit
+  $(top_builddir)/lib/libtestmain.la
diff --git a/mcrouter/lib/fbi/network.h b/mcrouter/lib/fbi/network.h
index e3247d36..53c5f41f 100644
--- a/mcrouter/lib/fbi/network.h
+++ b/mcrouter/lib/fbi/network.h
@@ -10,6 +10,10 @@
 #include <netinet/in.h>
 #include <stdbool.h>
 
+#ifndef s6_addr32
+  #define s6_addr32 __u6_addr.__u6_addr32
+#endif
+
 __BEGIN_DECLS
 
 typedef struct {
diff --git a/mcrouter/lib/fbi/sfrlock.c b/mcrouter/lib/fbi/sfrlock.c
deleted file mode 100644
index 72fd66e7..00000000
--- a/mcrouter/lib/fbi/sfrlock.c
+++ /dev/null
@@ -1,91 +0,0 @@
-/*
- *  Copyright (c) 2016, Facebook, Inc.
- *
- *  This source code is licensed under the MIT license found in the LICENSE
- *  file in the root directory of this source tree.
- *
- */
-#include "sfrlock.h"
-
-#include <limits.h>
-#include <linux/futex.h>
-#include <sys/syscall.h>
-#include <unistd.h>
-
-#include "mcrouter/lib/fbi/util.h"
-
-void sfrlock_init(sfrlock_t *l) {
-  l->value = 0;
-  l->waiters = 0;
-}
-
-void sfrlock_rdlock_contended(sfrlock_t *l) {
-  uint32_t oldv;
-  uint32_t newv;
-
-  __sync_fetch_and_add(&l->waiters, 1);
-
-  newv = ACCESS_ONCE(l->value);
-  do {
-    oldv = newv;
-
-    /* Wait for the write lock to be released. */
-    while (oldv & SFRLOCK_WRITE_LOCKED) {
-      syscall(SYS_futex, &l->value, FUTEX_WAIT | FUTEX_PRIVATE_FLAG, oldv,
-              NULL, NULL, 0);
-      oldv = ACCESS_ONCE(l->value);
-    }
-
-    /* Try to increment the reader count. */
-    newv = __sync_val_compare_and_swap(&l->value, oldv, oldv + 1);
-  } while (oldv != newv);
-
-  __sync_fetch_and_sub(&l->waiters, 1);
-}
-
-void sfrlock_wake_waiters(sfrlock_t *l) {
-  syscall(SYS_futex, &l->value, FUTEX_WAKE | FUTEX_PRIVATE_FLAG, INT_MAX,
-          NULL, NULL, 0);
-}
-
-void sfrlock_wrlock_contended(sfrlock_t *l) {
-  uint32_t oldv;
-  uint32_t newv;
-
-  __sync_fetch_and_add(&l->waiters, 1);
-
-  /*
-   * The block below is very similar to the read lock acquisition, except that
-   * instead of incrementing the read count, it sets the write lock bit once
-   * the potential current writer is gone (i.e., when the write lock is not
-   * held).
-   */
-  newv = ACCESS_ONCE(l->value);
-  do {
-    oldv = newv;
-
-    /* Wait for the write lock to be released. */
-    while (oldv & SFRLOCK_WRITE_LOCKED) {
-      syscall(SYS_futex, &l->value, FUTEX_WAIT | FUTEX_PRIVATE_FLAG, oldv,
-              NULL, NULL, 0);
-      oldv = ACCESS_ONCE(l->value);
-    }
-
-    /* Try to take the write lock. */
-    newv = __sync_val_compare_and_swap(&l->value, oldv,
-                                       oldv | SFRLOCK_WRITE_LOCKED);
-  } while (oldv != newv);
-
-  /*
-   * We own the write lock. Now we just have to wait any potential readers to
-   * release the lock before we can continue.
-   */
-  oldv |= SFRLOCK_WRITE_LOCKED;
-  while (oldv != SFRLOCK_WRITE_LOCKED) {
-    syscall(SYS_futex, &l->value, FUTEX_WAIT | FUTEX_PRIVATE_FLAG, oldv,
-            NULL, NULL, 0);
-    oldv = ACCESS_ONCE(l->value);
-  }
-
-  __sync_fetch_and_sub(&l->waiters, 1);
-}
diff --git a/mcrouter/lib/fbi/sfrlock.cpp b/mcrouter/lib/fbi/sfrlock.cpp
new file mode 100644
index 00000000..e2f40f30
--- /dev/null
+++ b/mcrouter/lib/fbi/sfrlock.cpp
@@ -0,0 +1,91 @@
+/*
+ *  Copyright (c) 2016, Facebook, Inc.
+ *
+ *  This source code is licensed under the MIT license found in the LICENSE
+ *  file in the root directory of this source tree.
+ *
+ */
+#include "sfrlock.h"
+
+#include <limits.h>
+#include <folly/detail/Futex.h>
+#include <sys/syscall.h>
+#include <unistd.h>
+
+#include "mcrouter/lib/fbi/util.h"
+
+void sfrlock_init(sfrlock_t *l) {
+  l->value = 0;
+  l->waiters = 0;
+}
+
+void sfrlock_rdlock_contended(sfrlock_t *l) {
+  uint32_t oldv;
+  uint32_t newv;
+
+  __sync_fetch_and_add(&l->waiters, 1);
+
+  newv = ACCESS_ONCE(l->value);
+  do {
+    oldv = newv;
+
+    /* Wait for the write lock to be released. */
+    while (oldv & SFRLOCK_WRITE_LOCKED) {
+      folly::detail::Futex<std::atomic> f(l->value);
+      f.futexWait(oldv);
+      oldv = ACCESS_ONCE(l->value);
+    }
+
+    /* Try to increment the reader count. */
+    newv = __sync_val_compare_and_swap(&l->value, oldv, oldv + 1);
+  } while (oldv != newv);
+
+  __sync_fetch_and_sub(&l->waiters, 1);
+}
+
+void sfrlock_wake_waiters(sfrlock_t *l) {
+  folly::detail::Futex<std::atomic> f(l->value);
+  f.futexWake();
+}
+
+void sfrlock_wrlock_contended(sfrlock_t *l) {
+  uint32_t oldv;
+  uint32_t newv;
+
+  __sync_fetch_and_add(&l->waiters, 1);
+
+  /*
+   * The block below is very similar to the read lock acquisition, except that
+   * instead of incrementing the read count, it sets the write lock bit once
+   * the potential current writer is gone (i.e., when the write lock is not
+   * held).
+   */
+  newv = ACCESS_ONCE(l->value);
+  do {
+    oldv = newv;
+
+    /* Wait for the write lock to be released. */
+    while (oldv & SFRLOCK_WRITE_LOCKED) {
+      folly::detail::Futex<std::atomic> f(l->value);
+      f.futexWait(oldv);
+      oldv = ACCESS_ONCE(l->value);
+    }
+
+    /* Try to take the write lock. */
+    newv = __sync_val_compare_and_swap(&l->value, oldv,
+                                       oldv | SFRLOCK_WRITE_LOCKED);
+  } while (oldv != newv);
+
+  /*
+   * We own the write lock. Now we just have to wait any potential readers to
+   * release the lock before we can continue.
+   */
+  oldv |= SFRLOCK_WRITE_LOCKED;
+  while (oldv != SFRLOCK_WRITE_LOCKED) {
+    folly::detail::Futex<std::atomic> f(l->value);
+    f.futexWait(oldv);
+    oldv = ACCESS_ONCE(l->value);
+  }
+
+  __sync_fetch_and_sub(&l->waiters, 1);
+}
diff --git a/mcrouter/lib/fbi/test/Makefile.am b/mcrouter/lib/fbi/test/Makefile.am
index 1197e6da..595e6cff 100644
--- a/mcrouter/lib/fbi/test/Makefile.am
+++ b/mcrouter/lib/fbi/test/Makefile.am
@@ -14,6 +14,4 @@ mcrouter_fbi_test_CPPFLAGS = \
 
 mcrouter_fbi_test_LDADD = \
 	$(top_builddir)/lib/libmcrouter.a \
-	$(top_builddir)/lib/libtestmain.la \
-	-lfollylogging \
-	-lfollyinit
+	$(top_builddir)/lib/libtestmain.la
diff --git a/mcrouter/lib/network/AsyncMcClientImpl.cpp b/mcrouter/lib/network/AsyncMcClientImpl.cpp
index e024fc3a..1006e4d3 100644
--- a/mcrouter/lib/network/AsyncMcClientImpl.cpp
+++ b/mcrouter/lib/network/AsyncMcClientImpl.cpp
@@ -908,24 +908,6 @@ void AsyncMcClientImpl::updateWriteTimeout(std::chrono::milliseconds timeout) {
 }
 
 double AsyncMcClientImpl::getRetransmissionInfo() {
-  if (socket_ != nullptr) {
-    struct tcp_info tcpinfo;
-    socklen_t len = sizeof(struct tcp_info);
-
-    auto& socket = dynamic_cast<folly::AsyncSocket&>(*socket_);
-
-    if (socket.getSockOpt(IPPROTO_TCP, TCP_INFO, &tcpinfo, &len) == 0) {
-      const uint64_t totalKBytes = socket.getRawBytesWritten() / 1000;
-      if (totalKBytes == lastKBytes_) {
-        return 0.0;
-      }
-      const auto retransPerKByte = (tcpinfo.tcpi_total_retrans - lastRetrans_) /
-          (double)(totalKBytes - lastKBytes_);
-      lastKBytes_ = totalKBytes;
-      lastRetrans_ = tcpinfo.tcpi_total_retrans;
-      return retransPerKByte;
-    }
-  }
   return -1.0;
 }
 } // memcache
diff --git a/mcrouter/lib/network/AsyncMcServer.cpp b/mcrouter/lib/network/AsyncMcServer.cpp
index f0fc9fe0..e6bf9a01 100644
--- a/mcrouter/lib/network/AsyncMcServer.cpp
+++ b/mcrouter/lib/network/AsyncMcServer.cpp
@@ -46,11 +46,7 @@ class ShutdownPipe : public folly::EventHandler {
  public:
   ShutdownPipe(AsyncMcServer& server, folly::EventBase& evb)
       : folly::EventHandler(&evb), server_(server) {
-    fd_ = eventfd(0, 0);
-    if (UNLIKELY(fd_ == -1)) {
-      throw std::runtime_error(
-          "Unexpected file descriptor (-1) in ShutdownPipe");
-    }
+    fd_ = -1;
     changeHandlerFD(fd_);
     registerHandler(EV_READ);
   }
diff --git a/mcrouter/lib/network/Makefile.am b/mcrouter/lib/network/Makefile.am
index 4f466227..00df838f 100644
--- a/mcrouter/lib/network/Makefile.am
+++ b/mcrouter/lib/network/Makefile.am
@@ -10,11 +10,7 @@ mock_mc_server_SOURCES = \
 
 mock_mc_server_CPPFLAGS = -I$(top_srcdir)/..
 
-mock_mc_server_LDADD = \
-	$(top_builddir)/lib/libmcrouter.a \
-	-lfolly \
-	-lfollyinit \
-	-lfollylogging
+mock_mc_server_LDADD = $(top_builddir)/lib/libmcrouter.a -lwangle -lfolly
 
 libtest_util_a_SOURCES = \
   test/ClientSocket.cpp \
diff --git a/mcrouter/lib/network/test/Makefile.am b/mcrouter/lib/network/test/Makefile.am
index 916b3385..b3fbc910 100644
--- a/mcrouter/lib/network/test/Makefile.am
+++ b/mcrouter/lib/network/test/Makefile.am
@@ -27,5 +27,5 @@ mcrouter_network_test_LDADD = \
   $(top_builddir)/lib/libmcrouter.a \
   $(top_builddir)/lib/libtestmain.la \
   $(top_builddir)/lib/network/libtest_util.a \
-	-lfollylogging \
-	-lfollyinit
+  -lwangle \
+  -lfolly
diff --git a/mcrouter/lib/test/Makefile.am b/mcrouter/lib/test/Makefile.am
index 1ffa7b08..51d262df 100644
--- a/mcrouter/lib/test/Makefile.am
+++ b/mcrouter/lib/test/Makefile.am
@@ -22,6 +22,4 @@ mcrouter_lib_test_CPPFLAGS = \
 
 mcrouter_lib_test_LDADD = \
   $(top_builddir)/lib/libmcrouter.a \
-  $(top_builddir)/lib/libtestmain.la \
-	-lfollylogging \
-	-lfollyinit
+  $(top_builddir)/lib/libtestmain.la
diff --git a/mcrouter/mcrouter_config.cpp b/mcrouter/mcrouter_config.cpp
index c5458c74..2e5d35be 100644
--- a/mcrouter/mcrouter_config.cpp
+++ b/mcrouter/mcrouter_config.cpp
@@ -139,6 +139,8 @@ folly::dynamic readStaticJsonFile(folly::StringPiece file) {
   return folly::parseJson(contents);
 }
 
-} // mcrouter
-} // memcache
-} // facebook
+void initStandaloneSSL() {}
+
+} // namespace mcrouter
+} // namespace memcache
+} // namespace facebook
diff --git a/mcrouter/routes/test/Makefile.am b/mcrouter/routes/test/Makefile.am
index d567064f..396569ec 100644
--- a/mcrouter/routes/test/Makefile.am
+++ b/mcrouter/routes/test/Makefile.am
@@ -20,6 +20,6 @@ mcrouter_routes_test_LDADD = \
   $(top_builddir)/libmcroutercore.a \
   $(top_builddir)/lib/libmcrouter.a \
   $(top_builddir)/lib/libtestmain.la \
-  -lfollybenchmark \
-  -lfollyinit \
-  -lfollylogging
+  -lwangle \
+  -lfolly \
+  -lfollybenchmark
diff --git a/mcrouter/stats.cpp b/mcrouter/stats.cpp
index eb588665..0f63166f 100644
--- a/mcrouter/stats.cpp
+++ b/mcrouter/stats.cpp
@@ -487,7 +487,7 @@ void prepare_stats(CarbonRouterInstanceBase& router, stat_t* stats) {
         pr->fiberManager().fibersAllocated();
     stats[fibers_pool_size_stat].data.uint64 +=
         pr->fiberManager().fibersPoolSize();
-    stats[fibers_stack_high_watermark_stat].data.uint64 = std::max(
+    stats[fibers_stack_high_watermark_stat].data.uint64 = std::max<int>(
         stats[fibers_stack_high_watermark_stat].data.uint64,
         pr->fiberManager().stackHighWatermark());
     stats[duration_us_stat].data.dbl += pr->stats().durationUs().value();
diff --git a/mcrouter/test/cpp_unit_tests/Makefile.am b/mcrouter/test/cpp_unit_tests/Makefile.am
index ed6b723a..66b85418 100644
--- a/mcrouter/test/cpp_unit_tests/Makefile.am
+++ b/mcrouter/test/cpp_unit_tests/Makefile.am
@@ -26,5 +26,5 @@ mcrouter_test_LDADD = \
   $(top_builddir)/lib/libmcrouter.a \
   $(top_builddir)/lib/libtestmain.la \
   $(top_builddir)/lib/network/libtest_util.a \
-	-lfollylogging \
-	-lfollyinit
+  -lwangle \
+  -lfolly
diff --git a/mcrouter/tools/mcpiper/Makefile.am b/mcrouter/tools/mcpiper/Makefile.am
index f6a1272a..5a23136d 100644
--- a/mcrouter/tools/mcpiper/Makefile.am
+++ b/mcrouter/tools/mcpiper/Makefile.am
@@ -31,8 +31,6 @@ mcpiper_SOURCES = \
 
 mcpiper_LDADD = \
 	$(top_srcdir)/lib/libmcrouter.a \
-	-lfolly \
-	-lfollylogging \
-	-lfollyinit
+	-lfolly
 
 mcpiper_CPPFLAGS = -I$(top_srcdir)/..

