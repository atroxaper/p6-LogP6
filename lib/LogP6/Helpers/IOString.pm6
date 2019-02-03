unit class LogP6::Helpers::IOString is IO::Handle;

has Str $!writed;

submethod TWEAK {
	self.encoding: 'utf8';
}

method WRITE(IO::Handle:D: Blob:D \data --> Bool:D) {
	$!writed //= '';
	$!writed ~= data.decode;
	True;
}

method writed(LogP6::Helpers::IOString:D: --> Str) {
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

multi method Str(LogP6::Helpers::IOString:D:) {
	$!writed;
}

multi method gist(LogP6::Helpers::IOString:D:) {
	$!writed;
}