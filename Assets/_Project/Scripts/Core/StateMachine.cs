namespace Nooni.Core
{
    public interface IState
    {
        void Enter();
        void Tick();
        void Exit();
    }

    /// <summary>Minimal state machine. Owners drive it from their own Update.</summary>
    public sealed class StateMachine
    {
        public IState Current { get; private set; }

        public void Set(IState next)
        {
            if (next == Current) return;
            Current?.Exit();
            Current = next;
            Current?.Enter();
        }

        public void Tick() => Current?.Tick();
    }
}
