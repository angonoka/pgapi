##########################################################################
#
#  Implements "fuzzy" real numbers (two are equal when they are "close enough")
#

package Value::Real;
my $pkg = 'Value::Real';

use strict;
use vars qw(@ISA);
@ISA = qw(Value);

use overload
       '+'   => \&add,
       '-'   => \&sub,
       '*'   => \&mult,
       '/'   => \&div,
       '**'  => \&power,
       '.'   => \&Value::_dot,
       'x'   => \&Value::cross,
       '<=>' => \&compare,
       'neg' => sub {$_[0]->neg},
       'abs' => sub {$_[0]->abs},
       'sqrt'=> sub {$_[0]->sqrt},
       'exp' => sub {$_[0]->exp},
       'log' => sub {$_[0]->log},
       'sin' => sub {$_[0]->sin},
       'cos' => sub {$_[0]->cos},
     'atan2' => \&atan2,
  'nomethod' => \&Value::nomethod,
        '""' => \&stringify;

#
#  Check that the input is a real number or a formula
#  Make a formula if either part is a formula
#
sub new {
  my $self = shift; my $class = ref($self) || $self;
  my $x = shift; $x = [$x,@_] if scalar(@_) > 0;
  $x = $x->data if ref($x) eq $pkg;
  Value::Error("Can't convert ".Value::showClass($x)." to a Real Number") if Value::isValue($x);
  $x = [$x] unless ref($x) eq 'ARRAY';
  Value::Error("Can't convert ARRAY of length ".scalar(@{$x})." to a Real Number") 
    unless (scalar(@{$x}) == 1);
  Value::Error("Real Number can't be ".Value::showClass($x->[0]))
     unless (Value::isRealNumber($x->[0]));
  return $self->formula($x->[0]) if Value::isFormula($x->[0]);
  bless {data => $x}, $class;
}

#
#  Create a new formula from the number
#
sub formula {
  my $self = shift; my $value = shift;
  Value::Formula->new($value);
}

#
#  Return the real number type
#
sub typeRef {return $Value::Type{number}}

#
#  return the real number
#
sub value {(shift)->{data}[0]}

##################################################

#
#  Return a real if it already is one, otherwise make it one
#
sub promote {
  my $x = shift;
  return $x if (ref($x) eq $pkg && scalar(@_) == 0);
  return $pkg->new($x,@_);
}
#
#  Get the data from the promoted item
#
sub promoteData {@{(promote(shift))->data}}

##################################################
#
#  Binary operations
#

sub add {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->add($l,!$flag)}
  $r = promote($r);
  return $pkg->make($l->{data}[0] + $r->{data}[0]);
}

sub sub {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->sub($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  return $pkg->make($l->{data}[0] - $r->{data}[0]);
}

sub mult {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->mult($l,!$flag)}
  $r = promote($r);
  return $pkg->make($l->{data}[0]*$r->{data}[0]);
}

sub div {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->div($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  Value::Error("Division by zero") if $r == 0;
  return $pkg->make($l->{data}[0]/$r->{data}[0]);
}

sub power {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->power($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  return $pkg->make($l->{data}[0]**$r->{data}[0]);
 }

sub compare {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->compare($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  my ($a,$b) = ($l->{data}[0],$r->{data}[0]);
  my $tolerance = $$Value::context->flag('tolerance');
  if ($$Value::context->flag('tolType') eq 'relative') {
    my $zeroLevel = $$Value::context->flag('zeroLevel');
    if (abs($a) < $zeroLevel || abs($b) < $zeroLevel) {
      $tolerance = $$Value::context->flag('zeroLevelTol');
    } else {
      $tolerance = $tolerance * abs($a);
    }
  }
  return 0 if abs($a-$b) < $tolerance;
  return $a <=> $b;
}

##################################################
#
#   Numeric functions
#

sub abs {$pkg->make(CORE::abs(shift->{data}[0]))}
sub neg {$pkg->make(-(shift->{data}[0]))}
sub exp {$pkg->make(CORE::exp(shift->{data}[0]))}
sub log {$pkg->make(CORE::log(shift->{data}[0]))}

sub sqrt {
  my $self = shift;
  return $pkg->make(0) if $self == 0;
  return $pkg->make(CORE::sqrt($self->{data}[0]));
}

##################################################
#
#   Trig functions
#

sub sin {$pkg->make(CORE::sin(shift->{data}[0]))}
sub cos {$pkg->make(CORE::cos(shift->{data}[0]))}

sub atan2 {
  my ($l,$r,$flag) = @_;
  if ($flag) {my $tmp = $l; $l = $r; $r = $l}
  return $pkg->make(CORE::atan2($l->{data}[0],$r->{data}[0]));
}

##################################################

sub stringify {shift->string}

sub string {
  my $self = shift; my $equation = shift; my $parens = shift;
  my $n = $self->{data}[0];
  my $format = $$Value::context->{format}{number};
  $n = sprintf($format,$n) if $format; #  use the specified precision, if any
  $n = uc($n); # force e notation to E
  $n = 0 if $self == 0; # make near zero print as zero
  $n = "(".$n.")" if ($n < 0 || $n =~ m/E/i) && defined($parens);
  return $n;
}

sub TeX {
  my $n = (shift)->string(@_);
  $n =~ s/E\+?(-?)0*([^)]*)/\\times 10^{$1$2}/i; # convert E notation to x10^(...)
  return $n;
}


###########################################################################

1;

