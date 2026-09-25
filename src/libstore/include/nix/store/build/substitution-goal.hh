#pragma once
///@file

#include "nix/store/build/worker.hh"
#include "nix/store/store-api.hh"
#include "nix/store/build/goal.hh"
#include <coroutine>
#include <future>
#include <source_location>

namespace nix {

class PathSubstitutionGoal : public Goal
{
    /**
     * The store path that should be realised through a substitute.
     */
    StorePath storePath;

    /**
     * Whether, if there are not substituters, to return ecNoSubstituters or ecFailed.
     */
    bool pathRequired;

    /**
     * Whether to try to repair a valid path.
     */
    RepairFlag repair;

    /**
     * The substituter thread.
     */
    std::thread thr;

    std::unique_ptr<MaintainCount<uint64_t>> maintainExpectedSubstitutions, maintainRunningSubstitutions,
        maintainExpectedNar, maintainExpectedDownload;

    /**
     * Content address for recomputing store path
     */
    std::optional<ContentAddress> ca;

    enum class SubstitutionResult {
        SubstituterFailed,
        SubstituteGone,
        Ok,
    };

    /**
     * @param provenanceOut Set to the provenance of the substituted
     * path on success.
     */
    BasicCo<SubstitutionResult> tryToRun(
        StorePath subPath,
        nix::ref<Store> sub,
        std::shared_ptr<const ValidPathInfo> info,
        ActivityId parentAct,
        std::shared_ptr<const Provenance> & provenanceOut);

public:
    PathSubstitutionGoal(
        const StorePath & storePath,
        Worker & worker,
        bool pathRequired,
        RepairFlag repair = NoRepair,
        std::optional<ContentAddress> ca = std::nullopt);

    ~PathSubstitutionGoal();

    std::string key() override
    {
        return "a$" + std::string(storePath.name()) + "$" + worker.store.printStorePath(storePath);
    }

    const StorePath & getStorePath() const &
    {
        return storePath;
    }

    /**
     * The states.
     */
    Co init();

    /* Called by destructor, can't be overridden */
    void cleanup() override final;

    JobCategory jobCategory() const override
    {
        return JobCategory::Substitution;
    };

    Done doneFailure(ExitCode result, BuildResult::Failure failure, ActivityId act = 0);
};

} // namespace nix
