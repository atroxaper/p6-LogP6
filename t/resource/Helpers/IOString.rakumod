#| Helper class. String concatenation implementation of IO::Handle.
unit class IOString is IO::Handle;

has Str $!writed;
has Bool $!closed;

submethod TWEAK {
	self.encoding: 'utf8';
}

method WRITE(IO::Handle:D: Blob:D \data --> Bool:D) {
	$!writed //= '';
	$!writed ~= data.decode;
	True;
}

method writed(IOString:D: --> Str) {
	$!writed;
}

method clean() {
	my $return = $!writed;
	$!writed = Nil;
	return $return;
}

method READ(IO::Handle:D: Int:D \bytes --> Buf:D) {
	...
}

method EOF(IO::Handle:D: --> Bool:D) {
	False;
}

multi method Str(IOString:D:) {
	$!writed;
}

multi method gist(IOString:D:) {
	$!writed;
}

method close() {
	$!closed = True;
}

method closed() {
	$!closed;
}