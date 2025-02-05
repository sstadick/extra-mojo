"""A very basic CLI Opt Parser."""
from collections import Dict, Optional
from memory import Span
from utils import StringRef

import sys


@value
struct OptKind:
    """The viable types for an option to have."""

    var value: UInt8

    alias StringLike = Self(0)
    alias IntLike = Self(1)
    alias FloatLike = Self(2)
    alias BoolLike = Self(3)

    fn __init__(out self, value: UInt8):
        self.value = value

    fn __eq__(self, read other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, read other: Self) -> Bool:
        return not self == other

    fn __str__(read self) -> String:
        if self == Self.BoolLike:
            return "Bool"
        elif self == Self.IntLike:
            return "Int"
        elif self == Self.FloatLike:
            return "Float"
        else:
            # elif self == Self.StringLike:
            return "String"


@value
struct OptValue:
    """When an option is parsed, it's stored as an OptValue.

    To get a value out of
    """

    var kind: OptKind
    var _string: Optional[String]
    var _int: Optional[Int]
    var _float: Optional[Float64]
    var _bool: Optional[Bool]

    fn __init__(out self, str_value: String = ""):
        self.kind = OptKind.StringLike
        self._string = str_value
        self._int = None
        self._float = None
        self._bool = None

    fn __init__(out self, int_value: Int = 0):
        self.kind = OptKind.IntLike
        self._string = None
        self._int = int_value
        self._float = None
        self._bool = None

    fn __init__(out self, float_value: Float64 = 0.0):
        self.kind = OptKind.FloatLike
        self._string = None
        self._int = None
        self._float = float_value
        self._bool = None

    fn __init__(out self, bool_value: Bool = False):
        self.kind = OptKind.BoolLike
        self._string = None
        self._int = None
        self._float = None
        self._bool = bool_value

    # TODO: there's currently no good way to make a more generic compile time
    # `get[ReturnType: AnyType](read self) -> ReturnType` that can use the `ReturnType`
    # with `@parameter` to select what to return since types aren't comparable.
    fn get_string(read self) -> Optional[String]:
        return self._string

    fn get_int(read self) -> Optional[Int]:
        return self._int

    fn get_float(read self) -> Optional[Float64]:
        return self._float

    fn get_bool(read self) -> Optional[Bool]:
        return self._bool

    @staticmethod
    fn parse_string(read value: String) -> Self:
        return Self(value)

    @staticmethod
    fn parse_int(read value: String) raises -> Self:
        return Self(int(value))

    @staticmethod
    fn parse_float(read value: String) raises -> Self:
        return Self(float(value))

    @staticmethod
    fn parse_bool(read value: String) raises -> Self:
        if value.lower() == "true":
            return Self(True)
        elif value.lower() == "false":
            return Self(False)
        elif value.lower() == "1":
            return Self(True)
        elif value.lower() == "0":
            return Self(False)
        else:
            return Self(bool(value))

    @staticmethod
    fn parse_kind(kind: OptKind, read value: String) raises -> Self:
        # Get the value from the next string
        if kind == OptKind.BoolLike:
            return OptValue.parse_bool(value)
        elif kind == OptKind.StringLike:
            return OptValue.parse_string(value)
        elif kind == OptKind.IntLike:
            return OptValue.parse_int(value)
        elif kind == OptKind.FloatLike:
            return OptValue.parse_float(value)
        else:
            raise "Unsupported OptKind"


@value
struct OptConfig:
    var long_name: String
    var default_value: Optional[String]
    var value_kind: OptKind
    # if it's a flag, then it's value_kind needs to be bool
    var is_flag: Bool
    var description: String

    fn __init__(
        out self,
        owned long_name: String,
        value_kind: OptKind,
        *,
        is_flag: Bool = False,
        owned description: String = "",
        owned default_value: Optional[String] = None,
    ) raises:
        if is_flag and value_kind != OptKind.BoolLike and default_value:
            raise "If a DefinedArg `is_flag=True`, then the type of the argument must be `OptKind.BoolLike`, and a `default_value` must be supplied."
        self.long_name = long_name^
        self.value_kind = value_kind
        self.is_flag = is_flag
        self.description = description
        self.default_value = default_value


@value
struct ParsedOpts:
    var options: Dict[String, OptValue]
    var args: List[String]
    var help_msg: String

    fn __init__(out self, help_msg: String = ""):
        self.options = Dict[String, OptValue]()
        self.args = List[String]()
        self.help_msg = help_msg

    fn get_help_message(
        ref self,
    ) -> Pointer[String, __origin_of(self.help_msg)]:
        return Pointer.address_of(self.help_msg)

    fn get_string(read self, read key: String) raises -> String:
        var opt = self.options.get(key)
        if not key:
            raise String.write(key, " not found in options")

        var str_value = opt.value().get_string()
        if not str_value:
            raise String.write(
                "No string value for ",
                key,
                ". Check the specified option type.",
            )
        return str_value.value()

    fn get_int(read self, read key: String) raises -> Int:
        var opt = self.options.get(key)
        if not key:
            raise String.write(key, " not found in options")

        var int_value = opt.value().get_int()
        if not int_value:
            raise String.write(
                "No int value for ", key, ". Check the specified option type."
            )
        return int_value.value()

    fn get_float(read self, read key: String) raises -> Float64:
        var opt = self.options.get(key)
        if not key:
            raise String.write(key, " not found in options")

        var float_value = opt.value().get_float()
        if not float_value:
            raise String.write(
                "No float value for ", key, ". Check the specified option type."
            )
        return float_value.value()

    fn get_bool(read self, read key: String) raises -> Bool:
        var opt = self.options.get(key)
        if not key:
            raise String.write(key, " not found in options")

        var bool_value = opt.value().get_bool()
        if not bool_value:
            raise String.write(
                "No bool value for ", key, ". Check the specified option type."
            )
        return bool_value.value()


@value
struct OptParser:
    var options: Dict[String, OptConfig]
    var program_description: String
    var program_name: Optional[String]

    fn __init__(
        out self,
        program_description: String = "",
        program_name: Optional[String] = None,
    ) raises:
        self.options = Dict[String, OptConfig]()
        self.program_description = program_description
        self.program_name = program_name

        # Add help message by default, this means a user can override help if they want to
        self.add_opt(
            OptConfig(
                "help",
                OptKind.BoolLike,
                is_flag=True,
                default_value=String("False"),
                description="Show help message",
            )
        )

    fn add_opt(mut self, owned arg: OptConfig):
        self.options[arg.long_name] = arg

    fn help_msg(read self) -> String:
        @parameter
        fn write_arg_msg(mut writer: String, read opt: OptConfig):
            writer.write(
                "\t--",
                opt.long_name,
                " <",
                str(opt.value_kind),
                ">",
            )
            if opt.default_value:
                writer.write(" [Default: ", opt.default_value.value(), "]")
            else:
                writer.write(" [Required]")
            writer.write("\n")
            writer.write("\t\t", opt.description, "\n\n")

        var help_msg = String()
        help_msg.write(self.program_name.or_else("Executable"), "\n")
        help_msg.write(self.program_description, "\n\n")

        help_msg.write("FLAGS:\n")
        for kv in self.options.items():
            if not kv[].value.is_flag:
                continue
            write_arg_msg(help_msg, kv[].value)

        help_msg.write("OPTIONS:\n")
        for kv in self.options.items():
            if kv[].value.is_flag:
                continue
            write_arg_msg(help_msg, kv[].value)
        # TODO: create a USAGE message if we every add anything about expected ARGS
        return help_msg

    @staticmethod
    fn _strip_leading_dashes(arg: String) -> String:
        # TODO: use a string slice or something better here
        var i = 0
        while i < len(arg):
            if arg[i] != "-":
                break
            i += 1
        return arg[i:]

    fn parse_sys_args(mut self) raises -> ParsedOpts:
        var args = sys.argv()

        var exe = args[0]
        if not self.program_name:
            self.program_name = exe.__str__()

        var fixed = List[String]()
        var i = 1  # Skip the first arg
        while i < len(args):
            fixed.append(args[i].__str__())
            i += 1
        return self.parse_args(fixed)

    fn parse_args(read self, args: List[String]) raises -> ParsedOpts:
        var result = ParsedOpts(help_msg=self.help_msg())

        var i = 0
        while i < len(args):
            var arg = args[i]
            if arg.startswith("-"):
                var opt = self._strip_leading_dashes(arg)
                var opt_def = self.options.get(opt)
                if opt_def:
                    var opt_def = opt_def.value()
                    if not opt_def.is_flag:
                        i += 1
                        if i >= len(args):
                            raise String.write(
                                "Missing value for option: ", opt
                            )
                        var value = args[i]
                        # Get the value from the next string
                        result.options[opt] = OptValue.parse_kind(
                            opt_def.value_kind, value
                        )

                    else:
                        # It's a flag! invert the default value
                        result.options[opt] = OptValue(
                            not OptValue.parse_bool(
                                opt_def.default_value.value()
                            )
                            .get_bool()
                            .value()
                        )
                else:
                    raise String.write("No such option: ", opt)
            else:
                result.args.append(arg)
            i += 1

        # Fill in any args that haven't been seen with their defaults
        for arg in self.options.items():
            if not result.options.get(arg[].key):
                var default = arg[].value.default_value
                if not default:
                    raise String.write("No value provided for ", arg[].key)
                result.options[arg[].key] = OptValue.parse_kind(
                    arg[].value.value_kind, default.value()
                )

        return result
