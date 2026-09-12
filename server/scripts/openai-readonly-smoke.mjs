import { runReadonlySmoke, ReadonlySmokeFailure } from "../dist/local/readonly_smoke.js";

if (process.argv.length !== 3 || process.argv[2] !== "--live") {
  console.error("Aucun appel effectué. Ce test manuel exige --live et une configuration locale.");
  process.exitCode = 1;
} else {
  try {
    console.info(JSON.stringify(await runReadonlySmoke(process.env)));
  } catch (error) {
    // Serialize only the allowlisted diagnostic, never the error or its message.
    console.error(error instanceof ReadonlySmokeFailure
      ? JSON.stringify(error.diagnostic)
      : "Configuration ou démarrage du test local invalide ; aucun détail journalisé.");
    process.exitCode = 1;
  }
}
