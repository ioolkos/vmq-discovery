%% Copyright 2018 Octavo Labs AG (https://vernemq.com/company.html)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(vmq_discovery).

-author("Dairon Medina <me@dairon.org>").

-define(APP, vmq_discovery).
-define(DEFAULT_BACKEND, none).


-spec get_backend() -> atom().
get_backend() ->
    Backend =
     case application:get_env(?APP, discovery_backend) of
        {ok, Backend0} ->
            Backend0;
        undefined ->
            ?DEFAULT_BACKEND
    end,
    lager:info("Configured cluster discovery backend: ~s~n", [Backend]),
    Backend.


-spec maybe_init() -> ok | {error, Reason :: string()}.
maybe_init() ->
    Backend = get_backend(),
    case erlang:function_exported(Backend, init, 0) of
        true ->
            lager:debug("Initializing cluster discovery."),
            case Backend:init() of
                ok ->
                    lager:debug("Cluster discovery backend initialization succeeded."),
                    ok;
                {error, Reason} ->
                    lager:error("Failure initializing cluster discovery."),
                    {error, Reason}
            end;
        false ->
            ok
        end.

-spec get_cluster_nodes() -> {ok, Nodes :: list()} |
                             {error, Reason :: string()}.
get_cluster_nodes() ->
    Backend = get_backend(),
    Backend:list_nodes().

-spec maybe_register() -> ok.
maybe_register() ->
    Backend = get_backend(),
    case Backend:supports_registration() of
        true ->
            Backend:before_registration(),
            Backend:register(),
            Backend:after_registration();
        false ->
            lager:info("Cluster discovery backend ~s does not supports registration, skipping...", [Backend]),
            ok
    end.

-spec maybe_unregister() -> ok.
maybe_unregister() ->
    Backend = get_backend(),
    case Backend:supports_registration() of
        true ->
            Backend:unregister();
        false ->
            lager:info("Cluster discovery backend ~s does not supports registration, skipping...", [Backend]),
            ok
    end.


 -spec maybe_do_registration_delay() -> ok.
maybe_do_registration_delay() ->
  Backend = get_backend(),
    case Backend:supports_registration() of
        true  ->
            registration_delay();
        false ->
            rabbit_log:info("Cluster discovery backend ~s does not support registration, skipping registration delay.", [Backend]),
            ok
    end.

-spec registration_delay() -> ok.
registration_delay() ->
    case application:get_env(?APP, startup_delay) of
        {ok, Delay} when is_integer(Delay) ->
            DelayMs = Delay * 1000,
            rand:seed(exsplus),
            Jitter = max(1, rand:uniform(DelayMs)),
            FinalDelay = DelayMs + Jitter,
            lager:info("Waiting for ~p milliseconds before registration...", [FinalDelay]),
            timer:sleep(FinalDelay),
            ok;
        _Otherwise ->
            ok
    end.