'reach 0.1';

export const main = Reach.App(() => {
	const Deployer = Participant('Deployer', {
		...hasConsoleLogger,
		getTokens: Array(Token, 2),
		swapReady: Fun([Token], Null),
		showLp: Fun([UInt], Null),
	});

	const supply = UInt.max;

	const tokenSupplyObj = Struct([
		['secondSupply', UInt],
		['firstSupply', UInt],
	]);
	const SwapperApi = API('Swapper', {
		deposit: Fun([tokenSupplyObj], Bytes(5)),
		// withdraw: Fun([singleTokenSupplyObj],Null ),
		// swapAtoB: Fun([singleTokenSupplyObj], Null),
		// swapBtoA: Fun([singleTokenSupplyObj], Null)
	});
	init();
	Deployer.only(() => {
		const [tokAID, tokBID] = declassify(interact.getTokens);
		assume(tokAID != tokBID, 'I assumed tokens were not the same');
	});
	Deployer.publish(tokAID, tokBID);

	const lpTok = new Token({ supply });

	const singleTokenSupplyObj = Struct([
		['firstTok', Token],
		['secondTok', Token],
	]);
	Deployer.interact.log(lpTok);
	Deployer.interact.swapReady(lpTok);
	const [LPtot, Abal, Bbal] = parallelReduce([0, 0, 0])
		.paySpec([tokAID, tokBID])
		.invariant(
			balance(lpTok) == supply - LPtot &&
				balance(tokAID) == Abal &&
				balance(tokBID) == Bbal
		)
		.while(true)
		.api_(SwapperApi.deposit, (obj) => {
			const tokenStruct = tokenSupplyObj.fromObject(obj);
			const tokenObj = tokenSupplyObj.toObject(tokenStruct);
			check(tokenObj.firstSupply != 0);
			check(tokenObj.secondSupply != 0);
			const Ain = tokenObj.firstSupply;
			const Bin = tokenObj.secondSupply;
			return [
				[
					0,
					...[
						[Ain, tokAID],
						[Bin, tokBID],
					],
				],
				(alert) => {
					check(Ain != 0);
					check(Bin != 0);
					const AbalPrime = Abal + Ain;
					const BbalPrime = Bbal + Bin;
					const ABin = Ain * Bin; // 10000
					const denominator = AbalPrime * BbalPrime; // 40000
					// const mulZ = muldiv(Ain, Bin, AbalPrime * BbalPrime); //0.25

					// const z = ABin / denominator; // 0.25 but shows 0
					// cons mulz =
					const zTimesLPtot = mul(Bin / denominator, LPtot);
					// const final = zTimesLPtot / 100;

					const LPout =
						LPtot == 0
							? sqrt(Ain * Bin)
							: mul(
									div(muldiv(Ain, Bin, mul(AbalPrime, BbalPrime)), 100),
									LPtot
							  );

					Deployer.interact.showLp(zTimesLPtot);

					// Deployer.interact.showLp(mulZ);

					// Deployer.interact.showLp(z);

					// Deployer.interact.showLp(z);

					const LPtotPrime = LPtot + LPout;
					Deployer.interact.showLp(LPtot);

					Deployer.interact.showLp(LPtot);

					alert('pays!');

					transfer(LPout, lpTok).to(this);
					return [LPtotPrime, AbalPrime, BbalPrime];
				},
			];

			//check(Ain > 0, "tokAsupply insufficient")
			//check(Bin > 0, "tokBsupply insufficient")
		});
	transfer(balance(lpTok), lpTok).to(Deployer);
	transfer(balance(tokAID), tokAID).to(Deployer);
	transfer(balance(tokBID), tokBID).to(Deployer);
	transfer(balance()).to(Deployer);

	lpTok.burn();
	lpTok.destroy();

	commit();
	exit();
});
