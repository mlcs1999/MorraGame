"reach 0.1";

const [ isNumber, ZERO, ONE, TWO, THREE, FOUR, FIVE ] = makeEnum(6);
const [ isGuess, gZERO, gONE, gTWO, gTHREE, gFOUR, gFIVE, gSIX, gSEVEN, gEIGHT, gNINE, gTEN ] = makeEnum(11);
const [ isOutcome, B_WINS, DRAW, A_WINS ] = makeEnum(3);

const winner = (numberMilica, numberLazar, guessMilica, guessLazar) => {
  if (guessMilica == guessLazar) {
    return DRAW;
  } 
  else if ((numberMilica + numberLazar) == guessMilica) {
    return A_WINS;
  } 
  else if ((numberMilica + numberLazar) == guessLazar) {
    return B_WINS;
  } 
  //both missed
  else {
    return DRAW;
  }
};

assert(winner(ZERO, ZERO, gZERO, gONE) == A_WINS);
assert(winner(ZERO, ZERO, gTWO, gZERO) == B_WINS);
assert(winner(ZERO, ZERO, gZERO, gZERO) == DRAW);

forall(UInt, (numberMilica) =>
  forall(UInt, (numberLazar) =>
    forall(UInt, (guessMilica) =>
      forall(UInt, (guessLazar) =>
        assert(
          isOutcome(winner(numberMilica, numberLazar, guessMilica, guessLazar)))))));

forall(UInt, (numberMilica) =>
  forall(UInt, (numberLazar) =>
    forall(UInt, (guess) =>
      assert(winner(numberMilica, numberLazar, guess, guess) == DRAW))));

//participant interact interface
const Player = {
  ...hasRandom,
  getNumber: Fun([], UInt),
  getGuess: Fun([], UInt),
  seeOutcome: Fun([UInt], Null),
  informTimeout: Fun([], Null),
};

export const main = Reach.App(() => {
  const Milica = Participant("Milica", {
    //Milica's interact interface
    ...Player,
    wager: UInt,
    deadline: UInt,
  });
  const Lazar = Participant("Lazar", {
    //Lazar's interact interface
    ...Player,
    acceptWager: Fun([UInt], Null),
  });

  init();

  const informTimeout = () => {
    // step <-> local step, for both participant
    each([Milica, Lazar], () => {
      interact.informTimeout();
    });
  };

  //only - local step
  Milica.only(() => {
    const wager = declassify(interact.wager);
    const deadline = declassify(interact.deadline);
  });

  // consensus step
  Milica.publish(wager, deadline).pay(wager);
  //back to step     
  commit();

  Lazar.only(() => {
    interact.acceptWager(wager);
  });

  Lazar.pay(wager)
       .timeout(relativeTime(deadline), () => closeTo(Milica, informTimeout));

  //LOOP for the game on consesus step
  //Repeat until outcome is A_WINS or B_WINS
  var outcome = DRAW; //ser variable
  invariant(balance() == 2 * wager && isOutcome(outcome));
  while (outcome == DRAW) {
    commit();

    Milica.only(() => {
      //hide Milica's number
      const _numberMilica = interact.getNumber();
      const [_commitNumberMilica, _saltNumberMilica] = makeCommitment(interact, _numberMilica);
      const commitNumberMilica = declassify(_commitNumberMilica);

      //hide Milica's guess
      const _guessMilica = interact.getGuess();
      const [_commitGuessMilica, _saltGuessMilica] = makeCommitment(interact, _guessMilica);
      const commitGuessMilica = declassify(_commitGuessMilica);
    });

    Milica.publish(commitNumberMilica, commitGuessMilica)
          .timeout(relativeTime(deadline),() => {closeTo(Lazar, informTimeout);} );
    commit();

    unknowable(Lazar, Milica(_numberMilica, _saltNumberMilica, _guessMilica, _saltGuessMilica));

    Lazar.only(() => {
      const numberLazar = declassify(interact.getNumber());
      const guessLazar = declassify(interact.getGuess());
    });
    Lazar.publish(numberLazar, guessLazar)
         .timeout(relativeTime(deadline), () => closeTo(Milica, informTimeout));
    commit();

    Milica.only(() => {
      const saltNumberMilica = declassify(_saltNumberMilica);
      const saltGuessMilica = declassify(_saltGuessMilica);
      const numberMilica = declassify(_numberMilica);
      const guessMilica = declassify(_guessMilica);
    });

    Milica.publish(saltNumberMilica, numberMilica, saltGuessMilica, guessMilica)
          .timeout(relativeTime(deadline), () => closeTo(Lazar, informTimeout)); 

    //checking whether the information matches for the shown number and guess
    checkCommitment(commitNumberMilica, saltNumberMilica, numberMilica);
    checkCommitment(commitGuessMilica, saltGuessMilica, guessMilica);

    outcome = winner(numberMilica, numberLazar, guessMilica, guessLazar);
    continue;
  } 

  //after the loop, outcome must be A_WINS or B_WINS
  assert(outcome == A_WINS || outcome == B_WINS);

  transfer(2 * wager).to(outcome == A_WINS ? Milica : Lazar);
  commit();

  each([Milica, Lazar], () => {
    interact.seeOutcome(outcome);
  });
});
