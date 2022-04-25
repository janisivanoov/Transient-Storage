from vyper.interfaces import ERC20

struct Borrow:
    startingBalance: uint256
    from_: address
    token: ERC20
    amount: uint256


interface IStartCallback:
    # @notice Called on the `msg.sender` when they call into #start
    def started(data: Bytes[1024]): payable

FEE: immutable(uint256)

@external
def __init__(fee: uint256):
    FEE = fee


borrows: transient(DynArray[Borrow, 10])

alreadyBorrowedToken: transient(HashMap[bytes32, bool])

borrower: transient(address)


@external
def start(data: Bytes[1024]):
    assert self.borrower == empty(address), "Jerk boy u r out"

    self.borrower = msg.sender

    IStartCallback(msg.sender).started(data)

    for borrow in self.borrows:
        key: bytes32 = keccak256(_abi_encode(borrow.from_, borrow.token))
        assert borrow.token.balanceOf(borrow.from_) >= borrow.startingBalance + ((borrow.amount * FEE) / 10_000), "You must pay back the person you borrowed from!"

        self.alreadyBorrowedToken[key] = False

    self.borrows = []

    self.borrower = empty(address)


@external
def borrow(from_: address, token: ERC20, amount: uint256, to: address):
    assert msg.sender == self.borrower, "Must be called from within the IStartCallback#started"
    key: bytes32 = keccak256(_abi_encode(from_, token))
    assert not self.alreadyBorrowedToken[key], "Already borrowed this token from this address"

    self.borrows.append(Borrow({startingBalance: token.balanceOf(from_), from_: from_, token: token, amount: amount}))
    self.alreadyBorrowedToken[key] = True

    token.transferFrom(from_, to, amount)