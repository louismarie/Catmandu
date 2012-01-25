package Catmandu::Iterable;

use Catmandu::Sane;
use Catmandu::Util qw(:is :check);
require Catmandu::Iterator;
use Role::Tiny;

requires 'generator';

sub to_array {
    my ($self) = @_;
    my $next = $self->generator;
    my @a;
    my $data;
    while (defined($data = $next->())) {
        push @a, $data;
    }
    \@a;
}

sub count {
    my ($self) = @_;
    my $next = $self->generator;
    my $n = 0;
    while ($next->()) {
        $n++;
    }
    $n;
}

sub slice {
    my ($self, $start, $total) = @_;
    $start //= 0;
    Catmandu::Iterator->new(sub {
        sub {
            if (defined $total) {
                $total || return;
            }
            state $next = $self->generator;
            state $data;
            while (defined($data = $next->())) {
                if ($start > 0) {
                    $start--;
                    next;
                }
                if (defined $total) {
                    $total--;
                }
                return $data;
            }
            return;
        };
    });
}

sub each {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $n = 0;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data);
        $n++;
    }
    $n;
}

sub tap {
    my ($self, $sub) = @_;
    Catmandu::Iterator->new(sub {
        sub {
            state $next = $self->generator;
            state $data;
            if (defined($data = $next->())) {
                $sub->($data);
                return $data;
            }
            return;
        };
    });
}

sub any {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) && return 1;
    }
    return 0;
}

sub many {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $n = 0;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) && ++$n > 1 && return 1;
    }
    return 0;
}

sub all {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) || return 0;
    }
    return 1;
}

sub map {
    my ($self, $sub) = @_;
    Catmandu::Iterator->new(sub {
        sub {
            state $next = $self->generator;
            $sub->($next->() // return);
        };
    });
}

sub reduce {
    my $self = shift;
    my $sub  = pop;
    my $memo = pop;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        if (defined $memo) {
            $memo = $sub->($memo, $data);
        } else {
            $memo = $data;
        }
    }
    $memo;
}

sub first {
    $_[0]->generator->();
}

sub rest {
    $_[0]->slice(1);
}

sub take {
    my ($self, $n) = @_;
    Catmandu::Iterator->new(sub {
        sub {
            $n-- > 0 || return;
            state $next = $self->generator;
            $next->();
        };
    });
}

sub detect {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) && return $data;
    }
    return;
}

{
    my $to_sub = sub {
        if (is_string($_[0])) {
            my $key = $_[0];
            check_regex_ref(my $re = $_[1]);
            return sub {
                is_hash_ref($_[0]) || return;
                my $val = $_[0]->{$key}; is_value($val) && $val =~ $re;
            };
        } elsif (is_regex_ref($_[0])) {
            my $re = $_[0];
            return sub {
                is_value($_[0]) && $_[0] =~ $re;
            };
        }
        check_code_ref($_[0]);
    };

    sub select {
        my $self = shift; my $sub = $to_sub->(@_);
        Catmandu::Iterator->new(sub {
            sub {
                state $next = $self->generator;
                state $data;
                while (defined($data = $next->())) {
                    $sub->($data) && return $data;
                }
                return;
            };
        });
    }

    sub reject {
        my $self = shift; my $sub = $to_sub->(@_);
        Catmandu::Iterator->new(sub {
            sub {
                state $next = $self->generator;
                state $data;
                while (defined($data = $next->())) {
                    $sub->($data) || return $data;
                }
                return;
            };
        });
    }
};

sub pluck {
    my ($self, $key) = @_;
    Catmandu::Iterator->new(sub {
        sub {
            state $next = $self->generator;
            ($next->() // return)->{$key};
        };
    });
}

sub invoke {
    my ($self, $sym) = @_;
    Catmandu::Iterator->new(sub {
        sub {
            state $next = $self->generator;
            ($next->() // return)->$sym;
        };
    });
}

sub includes {
    my ($self, $data) = @_;
    $self->any(sub {
        is_same($data, $_[0]);
    });
}

sub group {
    my ($self, $size) = @_;
    Catmandu::Iterator->new(sub {
        sub {
            state $next = $self->generator;
            state $peek = $next->();

            $peek // return;

            Catmandu::Iterator->new(sub {
                 my $n = $size;
                 sub {
                    $n || return;
                    $n--;
                    my $data = $peek;
                    $peek = $next->();
                    $data;
                 };
            });
        };
    });
}

1;

=head1 NAME

Catmandu::Iterable - Base class for all iterable Catmandu classes

=head1 SYNOPSIS

    # Create an example Iterable using the Catmandu::Importer::Mock class
    my $it = Catmandu::Importer::Mock->new(size => 10); 

    my $array_ref = $it->to_array;
    my $num       = $it->count;

    # Loop functions
    $it->each(sub { print shift->{n} });

    my $item = $it->first;

    $it->rest
       ->each(sub { print shift->{n} });

    $it->slice(3,2)
       ->each(sub { print shift->{n} });

    $it->take(5)
       ->each(sub { print shift->{n} });

    $it->group(5)
       ->each(sub { printf "group of %d items\n" , shift->count});

    $it->tap(\&logme)->tap(\&printme)->tap(\&mailme)
       ->each(sub { print shift->{n} });

    # Select and loop
    my $item = $it->detect(sub { shift->{n} > 5 });

    $it->select(sub { shift->{n} > 5})
       ->each(sub { print shift->{n} });

    $it->reject(sub { shift->{n} > 5})
       ->each(sub { print shift->{n} });

    # Boolean
    if ($it->any(sub { shift->{n} > 5}) {
	 .. at least one n > 5 ..
    }

    if ($it->many(sub { shift->{n} > 5}) {
	 .. at least two n > 5 ..
    }

    if ($it->all(sub { shift->{n} > 5}) {
	 .. all n > 5 ..
    }

    # Modify and summary
    my $it2 = $it->map(sub { shift->{n} * 2 });

    my $sum = $it2->reduce(0,sub { 
		my ($prev,$this) = @_;
		$prev + $this;
		});

=head1 DESCRIPTION

The Catmandu::Iterable class provides many list methods to Iterators such as Importers and
Exporters. Most of the methods are lazy if the underlying datastream supports it. Beware of
idempotence: many iterators contain state information and calls will give different results on
a second invocation.

=head1 METHODS

=head2 to_array

Return all the items in the Iterator as an ARRAY ref.

=head2 count

Return the count of all the items in the Iterator.

=head3 LOOPING

=head2 each(\&callback)

For each item in the Iterator execute the callback function with the item as first argument. Returns
the number of items in the Iterator.

=head2 first

Return the first item from the Iterator.

=head2 rest

Returns an Iterator containing everything except the first item.

=head2 slice(INDEX,LENGTH)

Returns an Iterator starting at the item at INDEX returning at most LENGTH results.

=head2 take(NUM)

Returns an Iterator with the first NUM results.

=head2 group(NUM)

Splitting the Iterator into NUM parts and returning an Iterator for each part.

=head2 tap(\&callback)

Returns a copy of the Iterator and executing callback on each item. This method works
like the Unix L<tee> command.

=head2 detect(\&callback)

Returns the first item for which callback returns a true value.

=head2 select(\&callback)

Returns an Iterator for each item for which callback returns a true value.

=head2 reject(\&callback)

Returns an Iterator for each item for which callback returns a false value.

=head3 BOOLEAN FUNCTIONS

=head2 any(\&callback)

Returns true if at least one item generates a true value when executing callback.

=head2 many(\&callback)

Returns true if at least two items generate a true value when executing callback.

=head2 all(\&callback)

Returns true if all the items generate a true value when executing callback.

=head3 MAP & REDUCE

=head2 map(\&callback)

Returns a new Iterator containing for each item the result of the callback.

=head2 reduce([START],\&callback)

For each item in the Iterator execute &callback($prev,$item) where $prev is the
option START value or the result of the previous call to callback. Returns the
final result of the callback function.

=head1 SEE ALSO

L<Catmandu::Iterator>.

=cut

