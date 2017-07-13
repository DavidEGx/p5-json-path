use Test::Most;
use Carp;
use JSON::Path::Evaluator;
use JSON::MaybeXS qw/decode_json/;
use Scalar::Util qw(refaddr);

my @EXPRESSIONS = (
    '$..book[-1:]'  => single_ref( sub { $_[0]->{store}{book}[-1] } ),
    '$.nonexistent' => sub {
        my ( $refs, $obj ) = @_;
        is scalar @{$refs}, 0, 'Nonexistent path gives nothing back';
    },
    '$..nonexistent' => sub {
        my ( $refs, $obj ) = @_;
        is scalar @{$refs}, 0, 'Nonexistent path gives nothing back';
    },
    '$.complex_array[?(@.type.code=="CODE_ALPHA")]' => single_ref( sub { $_[0]->{complex_array}[0] } ),
    '$.array[-1:]'                                  => single_ref( sub { $_[0]->{array}[-1] } ),
    '$.array[0,1]'                                  => sub {
        my ( $refs, $obj ) = @_;
        for ( 0 .. $#{$refs} ) {
            my $ref      = $refs->[$_];
            my $expected = int rand 1000;
            is ref $ref, 'SCALAR', qq{Reftype $_ OK};
            ${$ref} = $expected;
            is $obj->{array}[$_], $expected, qq{Value $_ OK};
        }
    },
    '$.array[1:3]' => sub {
        my ( $refs, $obj ) = @_;
        for ( 0 .. $#{$refs} ) {
            my $ref      = $refs->[$_];
            my $expected = int rand 1000;
            is ref $ref, 'SCALAR', qq{Reftype $_ OK};
            ${$ref} = $expected;
            is $obj->{array}[ $_ + 1 ], $expected, qq{Value $_ OK};
        }
    },
    '$.complex_array[?($_->{weight} > 10)]' => sub {
        my ( $refs, $obj ) = @_;
        for ( 0 .. $#{$refs} ) {
            my $ref = $refs->[$_];
            is ref ${$ref}, 'HASH', qq{Reftype $_ OK};
            my $expected = int rand 1000;
            ${$ref}->{test_key} = $expected;
            if ( $_ == 0 ) {
                is $obj->{complex_array}[0]{test_key}, $expected, qq{Value $_ OK};
            }
            else {
                is $obj->{complex_array}[2]{test_key}, $expected, qq{Value $_ OK};
            }
        }
    },
    '$.simple'                   => single_ref( sub { $_[0]->{simple} } ),
    '$.long_hash.key1.subkey2'   => single_ref( sub { $_[0]->{long_hash}{key1}{subkey2} } ),
    '$.multilevel_array.1.0.0'   => single_ref( sub { $_[0]->{multilevel_array}[1][0][0] } ),
    '$.store.book[0].title'      => single_ref( sub { $_[0]->{store}{book}[0]{title} } ),
    '$.array[0]'                 => single_ref( sub { $_[0]->{array}[0] } ),
    '$.long_hash.key1'           => single_ref( sub { $_[0]->{long_hash}{key1} } ),
    '$.complex_array[?(@.quux)]' => sub {
        my ( $refs, $obj ) = @_;

        my @indices = grep { $obj->{complex_array}[$_]{quux} } ( 0 .. $#{ $obj->{complex_array} } );
        for ( 0 .. $#{$refs} ) {
            my $ref      = $refs->[$_];
            my $expected = int rand 1000;
            ${$ref} = $expected;
            is $obj->{complex_array}[ $indices[$_] ], $expected, q{Value OK};
        }
    },
    '$..foo' => sub {
        my ( $refs, $obj ) = @_;
        for ( 0 .. $#{$refs} ) {
            my $ref      = $refs->[$_];
            my $expected = int rand 1000;
            is ref $ref, 'SCALAR', qq{Reftype $_ OK};
            ${$ref} = $expected;
            is $obj->{complex_array}[$_]{foo}, $expected, qq{Value $_ OK};
        }
    },
    '$.store.book[*].title' => sub {
        my ( $refs, $obj ) = @_;
        for ( 0 .. $#{$refs} ) {
            my $ref      = $refs->[$_];
            my $expected = int rand 1000;
            is ref $ref, 'SCALAR', qq{Reftype $_ OK};
            ${$ref} = $expected;
            is $obj->{store}{book}[$_]{title}, $expected, qq{Value $_ OK};
        }
    },
    '$.long_hash.key1[subkey1,subkey2]' => sub {
        my ( $refs, $obj ) = @_;
        for ( 0 .. $#{$refs} ) {
            my $ref      = $refs->[$_];
            my $expected = int rand 1000;
            is ref $ref, 'SCALAR', qq{Reftype $_ OK};
            ${$ref} = $expected;
            if ( $_ == 0 ) {
                is $obj->{long_hash}{key1}{subkey1}, $expected, q{Value for 'subkey1' OK};
            }
            else {
                is $obj->{long_hash}{key1}{subkey2}, $expected, q{Value for 'subkey2' OK};
            }
        }
    },
);

while ( my $expression = shift @EXPRESSIONS ) {
    my $test = shift @EXPRESSIONS;
    my $json = sample_json();
    my $obj  = decode_json($json);

    subtest $expression => sub {
        my @refs;
        lives_ok { @refs = JSON::Path::Evaluator::evaluate_jsonpath( $obj, $expression, want_ref => 1 ) }
        q{evaluate() did not die};
        $test->( \@refs, $obj );
    };
}

done_testing;

sub single_ref {
    my $path = shift;
    return sub {
        my ( $refs, $obj ) = @_;
        my ($ref) = @{$refs};
        my $expected = int rand 1000;
        ${$ref} = $expected;
        is $path->($obj), $expected, q{Value OK};
    };
}

sub sample_json {

    my $data = <<END;
{
   "simple" : "Simple",
   "hash" : {
      "key" : "value"
   },
   "long_hash" : {
      "key1" : {
         "subkey1" : "1value1",
         "subkey2" : "1value2",
         "subkey3" : {
            "subsubkey1" : "1value11",
            "subsubkey2" : "1value12"
         }
      },
      "key2" : {
         "subkey1" : "2value1",
         "subkey2" : "2value2",
         "subkey3" : {
            "subsubkey1" : "2value11",
            "subsubkey2" : "2value12"
         }
      }
   },
   "array" : [
      "alpha",
      "beta",
      "gamma",
      "delta",
      "kappa"
   ],
   "complex_array" : [
      {
         "quux" : 1,
         "weight" : 20,
         "classification" : {
            "quux" : "omega",
            "quuy" : "omicron"
         },
         "foo" : "bar",
         "type" : {
            "name" : "Alpha",
            "code" : "CODE_ALPHA"
         }
      },
      {
         "quux" : 0,
         "weight" : 10,
         "classification" : {
            "quux" : "lambda",
            "quuy" : "nu"
         },
         "foo" : "baz",
         "type" : {
            "name" : "Beta",
            "code" : "CODE_BETA"
         }
      },
      {
         "weight" : 30,
         "classification" : {
            "quux" : "eta",
            "quuy" : "zeta"
         },
         "foo" : "bak",
         "type" : {
            "name" : "Gamma",
            "code" : "CODE_GAMMA"
         }
      },
      {
         "quux" : "cheese"
      }
      
   ],
   "multilevel_array" : [
      [
         [
            "alpha",
            "beta",
            "gamma"
         ],
         [
            "delta",
            "epsilon",
            "zeta"
         ]
      ],
      [
         [
            "eta",
            "theta",
            "iota"
         ],
         [
            "kappa",
            "lambda",
            "mu"
         ]
      ]
   ],
   "subkey1" : "DO NOT WANT",
   "store" : {
		"book": [
			{
				"category": "reference",
				"author":   "Nigel Rees",
				"title":    "Sayings of the Century",
				"price":    8.95
			},
			{
				"category": "fiction",
				"author":   "Evelyn Waugh",
				"title":    "Sword of Honour",
				"price":    12.99
			},
			{
				"category": "fiction",
				"author":   "Herman Melville",
				"title":    "Moby Dick",
				"isbn":     "0-553-21311-3",
				"price":    8.99
			},
			{
				"category": "fiction",
				"author":   "J. R. R. Tolkien",
				"title":    "The Lord of the Rings",
				"isbn":     "0-395-19395-8",
				"price":    22.99
			}
		]
   }
}
END
    return $data;
}

