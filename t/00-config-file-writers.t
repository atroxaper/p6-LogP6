use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::ConfigFile;
use lib './t/resource/Helpers';
use lib './t/resource/00-config-file';

# we use Unix style file paths in config file for the test
plan :skip-all<These tests do not work on Windows> if $*DISTRO.is-win;
plan 25;

CATCH { default {say .gist }}
my $folder = '/tmp/logp6'.IO;
mkdir $folder;
END {
  if $folder {
    *.unlink for $folder.dir;
    $folder.rmdir;
  }
}

my LogP6::ConfigFile $config .= new;
my ($w, $cn);
$cn = $config.parse-config('./t/resource/00-config-file/log-p6-file-writes.json');

is $cn.writers.elems, 7, 'parsed 7 writers';

$w = $cn.writers[0];
is $w.name, 'w1', 'w1 name';
is $w.pattern, '%msg', 'w1 pattern';
is $w.handle.Str, '/tmp/logp6/empty1.txt', 'w1 handle';
is $w.handle.out-buffer, 0, 'w1 out-buffer false(0)';
ok $w.auto-exceptions, 'w1 auto-exceptions';

$w = $cn.writers[1];
is $w.name, 'w2', 'w2 name';
is $w.pattern, '%level | %msg', 'w2 pattern';
is $w.handle, $*OUT, 'w2 handle';
is $w.handle.out-buffer, 100, 'w2 out-buffer false(0)';
is $cn.writers[2].handle, $*ERR, 'w3 handle';
nok $w.auto-exceptions, 'w2 auto-exceptions';

$w = $cn.writers[3];
is $w.name, 'w4', 'w4 name';
nok $w.pattern, 'w4 pattern';
is $w.handle.Str, '/tmp/logp6/empty4.txt', 'w4 handle';
nok $w.auto-exceptions, 'w4 auto-exceptions';

$w = $cn.writers[4];
is $w.name, 'w5', 'w5 name';
nok $w.pattern, 'w5 pattern';
nok $w.handle, 'w5 handle';
nok $w.auto-exceptions, 'w5 auto-exceptions';

$w = $cn.writers[5];
is $w.handle.out-buffer, 1000, 'w6 handle out-buffer 1000';

$w = $cn.writers[6];
is $w.name, 'w7', 'w7 name';
is $w.handle.Str, '/tmp/logp6/empty7.txt', 'w7 handle';

my $w0h = $cn.writers[0].handle.WHICH;
my $w3h = $cn.writers[3].handle.WHICH;
$cn = $config.parse-config('./t/resource/00-config-file/log-p6-file-writes.json');
is $w0h, $cn.writers[0].handle.WHICH, 'get file handle from cache';
is $w3h, $cn.writers[3].handle.WHICH, 'get custom handle from cache';

done-testing;
